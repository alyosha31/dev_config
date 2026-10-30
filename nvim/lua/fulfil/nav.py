"""Model-aware navigation for the Fulfil codebase, driven by init.lua next to it.

Pyright can't see through Fulfil's ORM: `Pool().get("sale.line")` hands back a
class it knows nothing about, and `self.party` reads as the Many2One field
object rather than the record it returns. So this keeps its own index of every
model -- its `__name__`, fields and methods, parsed with `ast` -- and works out
which model an expression holds by following pool lookups, ORM calls, loops and
relational fields. It only guesses from a variable's name when nothing else is
known, and says so.

    nav.py resolve ROOT CACHE_DIR FILE LINE COL {model,member}   (buffer on stdin)
    nav.py goto ROOT CACHE_DIR MODEL
    nav.py models ROOT CACHE_DIR

Every command prints one JSON object.
"""

import ast
import hashlib
import json
import os
import sys
import traceback
import warnings

# Old regex strings in the codebase trip SyntaxWarnings on every parse.
warnings.filterwarnings("ignore", category=SyntaxWarning)

INDEX_VERSION = 2
SOURCE_DIRS = ("fulfil", "fulfilio")
SKIP_DIRS = {"__pycache__", "node_modules", ".git"}

# Fields that wrap the real one: fields.Function(fields.Many2One(...), "getter").
WRAPPERS = {"Function", "MultiValue"}
# ORM calls that return records of the model they are called on.
RECORD_METHODS = {"search", "browse", "create", "copy"}
# Builtins whose result holds the same records as their first argument.
PASSTHROUGH = {"sorted", "list", "set", "tuple", "reversed", "iter", "next", "max", "min"}
SCOPES = (ast.FunctionDef, ast.AsyncFunctionDef, ast.Lambda)
# Names too generic to guess a model from (`data` is not ir.model.data).
NO_GUESS = {
    "args", "context", "data", "field", "fields", "id", "ids", "info", "item",
    "items", "key", "keys", "kwargs", "message", "name", "names", "obj", "objs",
    "options", "params", "payload", "res", "response", "result", "results",
    "row", "rows", "state", "status", "type", "vals", "value", "values",
}
# Name-only guesses beyond this many candidates are noise, not help.
MAX_GUESSES = 3


def _str(node):
    if isinstance(node, ast.Constant) and isinstance(node.value, str):
        return node.value
    return None


def _arg(call, index, keyword):
    for kw in call.keywords:
        if kw.arg == keyword:
            return kw.value
    return call.args[index] if index < len(call.args) else None


def _is_field(node):
    return (
        isinstance(node, ast.Call)
        and isinstance(node.func, ast.Attribute)
        and isinstance(node.func.value, ast.Name)
        and node.func.value.id == "fields"
    )


def _field(call):
    """Kind and target of a `fields.X(...)` definition."""
    kind = call.func.attr
    if kind in WRAPPERS:
        inner = _arg(call, 0, "field")
        return _field(inner) if _is_field(inner) else {"kind": kind}
    info = {"kind": kind}
    if kind in ("Many2One", "One2Many"):
        info["target"] = _str(_arg(call, 0, "model_name"))
    elif kind in ("Many2Many", "One2One"):
        relation = _str(_arg(call, 0, "relation_name"))
        via = _str(_arg(call, 2, "target"))
        if via:
            # The target model is wherever the relation model's `via` field points.
            info["relation"], info["via"] = relation, via
        else:
            # Many2Many("stock.move", None, None, ...): no relation model, the
            # first argument is the target itself.
            info["target"] = relation
    return info


def _field_info(value):
    """Kind and target of a class-body assignment that defines a field, or None."""
    if _is_field(value):
        return _field(value)
    if isinstance(value, ast.Call) and isinstance(value.func, ast.Name) and value.func.id.endswith("Field"):
        # UserField(...) and friends: the helper class knows the kind and target.
        return {"kind": value.func.id, "helper": value.func.id}
    return None


def _field_class(node):
    """For `class UserField(fields.Many2One)`, the kind it extends and the model
    its __init__ passes up, so fields built with it can be followed."""
    kind = next(
        (
            b.attr
            for b in node.bases
            if isinstance(b, ast.Attribute) and isinstance(b.value, ast.Name) and b.value.id == "fields"
        ),
        None,
    )
    if kind is None:
        return None, None
    for stmt in node.body:
        if isinstance(stmt, ast.FunctionDef) and stmt.name == "__init__":
            for call in ast.walk(stmt):
                if (
                    isinstance(call, ast.Call)
                    and isinstance(call.func, ast.Attribute)
                    and call.func.attr == "__init__"
                    and call.args
                    and _str(call.args[0])
                ):
                    return kind, _str(call.args[0])
    return kind, None


def _base_name(node):
    if isinstance(node, ast.Name):
        return node.id
    if isinstance(node, ast.Attribute):
        return node.attr
    return None


def _class_model(node):
    for stmt in node.body:
        if (
            isinstance(stmt, ast.Assign)
            and len(stmt.targets) == 1
            and isinstance(stmt.targets[0], ast.Name)
            and stmt.targets[0].id == "__name__"
        ):
            return _str(stmt.value)
    return None


def _index_file(path):
    try:
        with open(path, "rb") as fh:
            tree = ast.parse(fh.read(), path)
    except (OSError, SyntaxError, ValueError):
        return []
    classes = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.ClassDef):
            continue
        fields, methods = {}, {}
        for stmt in node.body:
            if isinstance(stmt, ast.Assign) and len(stmt.targets) == 1 and isinstance(stmt.targets[0], ast.Name):
                info = _field_info(stmt.value)
                if info is not None:
                    fields[stmt.targets[0].id] = dict(info, line=stmt.lineno)
            elif isinstance(stmt, (ast.FunctionDef, ast.AsyncFunctionDef)):
                methods[stmt.name] = stmt.lineno
        field_kind, field_target = _field_class(node)
        classes.append(
            {
                "name": node.name,
                "line": node.lineno,
                "bases": [b for b in map(_base_name, node.bases) if b],
                "model": _class_model(node),
                # `metaclass=PoolMeta` classes extend a model defined elsewhere.
                "extends": any(kw.arg == "metaclass" for kw in node.keywords),
                "fields": fields,
                "methods": methods,
                "field_kind": field_kind,
                "field_target": field_target,
            }
        )
    return classes


class Index:
    """Every class under fulfil/ and fulfilio/, cached on disk and refreshed
    file by file when mtimes change."""

    def __init__(self, root, cache_dir):
        self.root = root
        digest = hashlib.sha1(root.encode()).hexdigest()[:12]
        self.cache_path = os.path.join(cache_dir, f"index-{digest}.json")
        self.files = self._load()
        if self._refresh():
            self._save()

        self.models = {}  # model name -> classes declaring it
        self.classes = {}  # class name -> classes with that name
        for rel, data in self.files.items():
            for cls in data["classes"]:
                cls["file"] = rel
                self.classes.setdefault(cls["name"], []).append(cls)
                if cls["model"]:
                    self.models.setdefault(cls["model"], []).append(cls)
        for classes in self.models.values():
            # The defining class first, PoolMeta extensions after it.
            classes.sort(key=lambda c: c["extends"])

    def _load(self):
        try:
            with open(self.cache_path) as fh:
                data = json.load(fh)
        except (OSError, ValueError):
            return {}
        if data.get("version") != INDEX_VERSION or data.get("root") != self.root:
            return {}
        return data["files"]

    def _refresh(self):
        seen, changed = set(), False
        for top in SOURCE_DIRS:
            for dirpath, dirnames, filenames in os.walk(os.path.join(self.root, top)):
                dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
                for filename in filenames:
                    if not filename.endswith(".py"):
                        continue
                    path = os.path.join(dirpath, filename)
                    rel = os.path.relpath(path, self.root)
                    seen.add(rel)
                    mtime = os.stat(path).st_mtime
                    cached = self.files.get(rel)
                    if cached is None or cached["mtime"] != mtime:
                        self.files[rel] = {"mtime": mtime, "classes": _index_file(path)}
                        changed = True
        for rel in set(self.files) - seen:
            del self.files[rel]
            changed = True
        return changed

    def _save(self):
        os.makedirs(os.path.dirname(self.cache_path), exist_ok=True)
        tmp = f"{self.cache_path}.{os.getpid()}"
        with open(tmp, "w") as fh:
            json.dump({"version": INDEX_VERSION, "root": self.root, "files": self.files}, fh)
        os.replace(tmp, self.cache_path)

    def bases_of(self, cls):
        """The class and everything it inherits from, nearest first."""
        seen, queue, out = set(), [cls], []
        while queue:
            current = queue.pop(0)
            key = (current["file"], current["line"])
            if key in seen:
                continue
            seen.add(key)
            out.append(current)
            for base in current["bases"]:
                candidates = self.classes.get(base, [])
                # Prefer a base defined in the same file over a namesake elsewhere.
                same_file = [c for c in candidates if c["file"] == current["file"]]
                queue.extend(same_file or candidates)
        return out

    def model_classes(self, model):
        out, seen = [], set()
        for cls in self.models.get(model, []):
            for c in self.bases_of(cls):
                key = (c["file"], c["line"])
                if key not in seen:
                    seen.add(key)
                    out.append(c)
        return out

    def expand(self, field):
        """A field built with a helper class takes its kind and target from it."""
        helper = field.get("helper")
        for cls in self.classes.get(helper, []) if helper else []:
            if cls.get("field_kind"):
                return dict(field, kind=cls["field_kind"], target=cls["field_target"])
        return field

    def field(self, model, name):
        for cls in self.model_classes(model):
            if name in cls["fields"]:
                return self.expand(cls["fields"][name])
        return None

    def has_method(self, model, name):
        return any(name in cls["methods"] for cls in self.model_classes(model))

    def target_of(self, field):
        """The model a relational field points at, through a Many2Many's
        relation model when it has one."""
        field = self.expand(field)
        if field.get("target"):
            return field["target"]
        if field.get("relation") and field.get("via"):
            through = self.field(field["relation"], field["via"])
            return through.get("target") if through else None
        return None

    def field_target(self, model, name):
        field = self.field(model, name)
        return self.target_of(field) if field else None

    def models_using(self, class_name):
        """Models built on a mixin, directly or through other mixins."""
        names, found = {class_name}, set()
        for _ in range(4):
            more = set()
            for classes in self.classes.values():
                for cls in classes:
                    if names.intersection(cls["bases"]):
                        if cls["model"]:
                            found.add(cls["model"])
                        else:
                            more.add(cls["name"])
            if more <= names:
                break
            names |= more
        return sorted(found)

    def guess(self, name, near):
        """Models a variable called `name` most likely holds, best tier only.
        `near` is the model of the class the code is in: `lines` inside
        purchase.purchase means purchase.line before any other *.line."""
        if name in NO_GUESS:
            return []
        singulars = [name]
        if name.endswith("ies"):
            singulars.append(name[:-3] + "y")
        if name.endswith("es"):
            singulars.append(name[:-2])
        if name.endswith("s"):
            singulars.append(name[:-1])
        prefixes = []
        if near:
            parts = near.split(".")
            prefixes = [".".join(parts[:i]) for i in range(len(parts) - 1, 0, -1)]
        tiers = [[], [], []]
        for s in singulars:
            tiers[0] += [f"{p}.{s}" for p in prefixes]
            tiers[1].append(f"{s}.{s}")
            tiers[2] += sorted(m for m in self.models if m == s or m.endswith("." + s))
        for tier in tiers:
            hits = [m for m in dict.fromkeys(tier) if m in self.models]
            if hits:
                return hits
        return []

    def _location(self, rel, line, text):
        return {"file": os.path.join(self.root, rel), "line": line, "text": text}

    def model_locations(self, models):
        out = []
        for model in models:
            for cls in self.models.get(model, []):
                suffix = "  (extension)" if cls["extends"] else ""
                out.append(self._location(cls["file"], cls["line"], f"{model}  class {cls['name']}{suffix}"))
        return out

    def member_locations(self, model, name):
        out = []
        for cls in self.model_classes(model):
            if name in cls["fields"]:
                field = cls["fields"][name]
                text = f"{model}.{name}  {field['kind']} field in {cls['name']}"
                out.append(self._location(cls["file"], field["line"], text))
            if name in cls["methods"]:
                text = f"{model}.{name}()  in {cls['name']}"
                out.append(self._location(cls["file"], cls["methods"][name], text))
        return out


def _start(node):
    return (node.lineno, node.col_offset)


def _end(node):
    return (node.end_lineno, node.end_col_offset)


def _scope_nodes(scope):
    """Nodes that belong to `scope` itself, not to functions or classes inside it."""
    stack = list(ast.iter_child_nodes(scope))
    while stack:
        node = stack.pop()
        yield node
        if not isinstance(node, SCOPES + (ast.ClassDef,)):
            stack.extend(ast.iter_child_nodes(node))


def _pick(target, name, value, iterating=False):
    """What `name` is bound to when `value` is assigned to (or iterated into)
    `target`. Records don't care whether they come one at a time or in a list,
    so `x, = X.search(...)` and `for x in xs` both bind `x` to the whole value."""
    if isinstance(target, ast.Name):
        return value if target.id == name else None
    if isinstance(target, ast.Starred):
        return _pick(target.value, name, value)
    if isinstance(target, (ast.Tuple, ast.List)):
        for i, elt in enumerate(target.elts):
            inner = value
            if iterating and isinstance(value, ast.Call) and isinstance(value.func, ast.Name):
                # for i, line in enumerate(lines) / for a, b in zip(xs, ys)
                if value.func.id == "enumerate" and value.args:
                    inner = value.args[0] if i == 1 else None
                elif value.func.id == "zip" and i < len(value.args):
                    inner = value.args[i]
            found = _pick(elt, name, inner) if inner is not None else None
            if found is not None:
                return found
    return None


def _fail(message):
    return {"ok": False, "message": message}


class Resolver:
    def __init__(self, index, tree, line, col):
        self.index = index
        self.tree = tree
        self.parents = {}
        for parent in ast.walk(tree):
            for child in ast.iter_child_nodes(parent):
                self.parents[child] = parent
        self.target = self._node_at(line, col)
        self.trail = []  # how the answer was reached, for the message
        self.guessed = False
        self.failure = None
        self.cls = self._enclosing(self.target, (ast.ClassDef,))
        self.cls_models = self._class_models_quiet()

    def _node_at(self, line, col):
        best, best_size = None, None
        for node in ast.walk(self.tree):
            if not isinstance(node, (ast.expr, ast.arg)):
                continue
            if not _start(node) <= (line, col) < _end(node):
                continue
            size = (node.end_lineno - node.lineno, node.end_col_offset - node.col_offset)
            if best is None or size < best_size:
                best, best_size = node, size
        return best

    def _enclosing(self, node, types):
        while node is not None:
            node = self.parents.get(node)
            if isinstance(node, types):
                return node
        return None

    def _inside(self, node, ancestor):
        while node is not None:
            if node is ancestor:
                return True
            node = self.parents.get(node)
        return False

    def _scopes(self):
        out, node = [], self.target
        while True:
            node = self._enclosing(node, SCOPES)
            if node is None:
                return out + [self.tree]
            out.append(node)

    # -- self / cls ----------------------------------------------------------

    def _class_models_quiet(self):
        if self.cls is None:
            return []
        model = _class_model(self.cls)
        if model:
            return [model]
        # No __name__ here: inherited from a model base, or this is a mixin.
        for base in filter(None, map(_base_name, self.cls.bases)):
            for cls in self.index.classes.get(base, []):
                for c in self.index.bases_of(cls):
                    if c["model"]:
                        return [c["model"]]
        return self.index.models_using(self.cls.name)

    def _self_models(self):
        if not self.cls_models:
            return []
        if _class_model(self.cls) or len(self.cls_models) == 1:
            self.trail.append(f"self is {self.cls_models[0]}")
        else:
            self.trail.append(f"self is any model built on {self.cls.name}")
        return self.cls_models

    # -- expressions ---------------------------------------------------------

    def resolve(self, node, depth=0):
        if depth > 30 or node is None:
            return []
        if isinstance(node, ast.Constant):
            return [node.value] if _str(node) in self.index.models else []
        if isinstance(node, ast.Name):
            return self._name(node.id, _start(node), depth)
        if isinstance(node, ast.Attribute):
            if node.attr == "__class__":
                return self.resolve(node.value, depth + 1)
            out = []
            for model in self.resolve(node.value, depth + 1):
                target = self.index.field_target(model, node.attr)
                if target:
                    out.append(target)
                elif self.failure is None:
                    self.failure = self._not_a_link(model, node.attr)
            if out:
                self.trail.append(f".{node.attr} → {', '.join(dict.fromkeys(out))}")
            return list(dict.fromkeys(out))
        if isinstance(node, ast.Call):
            return self._call(node, depth)
        if isinstance(node, (ast.Subscript, ast.Starred, ast.NamedExpr)):
            return self.resolve(node.value, depth + 1)
        if isinstance(node, ast.BoolOp):
            for value in node.values:
                found = self.resolve(value, depth + 1)
                if found:
                    return found
            return []
        if isinstance(node, ast.IfExp):
            return self.resolve(node.body, depth + 1) or self.resolve(node.orelse, depth + 1)
        return []

    def _not_a_link(self, model, attr):
        field = self.index.field(model, attr)
        if field:
            return f"{attr} is a {field['kind']} field on {model}, not a link to another model"
        if self.index.has_method(model, attr):
            return f"{attr} is a method on {model} -- gM jumps to it"
        return f"{model} has no field called {attr}"

    def _call(self, node, depth):
        func = node.func
        if isinstance(func, ast.Attribute) and func.attr == "get" and node.args:
            name = _str(node.args[0])
            if name in self.index.models:
                self.trail.append(f'pool.get("{name}")')
                return [name]
        if isinstance(func, ast.Name) and func.id in PASSTHROUGH and node.args:
            return self.resolve(node.args[0], depth + 1)
        if isinstance(func, ast.Name) and func.id == "filter" and len(node.args) > 1:
            return self.resolve(node.args[1], depth + 1)
        if isinstance(func, ast.Attribute) and func.attr in RECORD_METHODS:
            return self.resolve(func.value, depth + 1)
        if isinstance(func, ast.Name):
            # SaleLine(line_id), cls(...): calling a model class gives its records.
            return self._name(func.id, _start(func), depth, guess=False)
        return []

    def _name(self, name, pos, depth, guess=True):
        if name in ("self", "cls"):
            found = self._self_models()
            if found:
                return found
        for scope in self._scopes():
            binding = self._binding(scope, name, pos)
            if binding is not None:
                found = self.resolve(binding, depth + 1)
                if found:
                    return found
                break  # bound to something we can't follow; maybe the name helps
            if self._is_param(scope, name):
                found = self._annotation(scope, name)
                if found:
                    return found
                break
        else:
            # Not bound anywhere: maybe an imported model class, like Sale.search(...).
            found = [c["model"] for c in self.index.classes.get(name, []) if c["model"]]
            if found:
                self.trail.append(f"{name} is {found[0]}")
                return found[:1]
        if guess:
            return self._guess(name)
        return []

    def _guess(self, name):
        if name in ("records", "record") and self.cls_models:
            found = self.cls_models
        else:
            found = self.index.guess(name, self.cls_models[0] if self.cls_models else None)
        if len(found) > MAX_GUESSES:
            self.failure = self.failure or f"Can't tell what {name} is: {len(found)} models fit that name"
            return []
        if found:
            self.guessed = True
            what = found[0] if len(found) == 1 else "one of " + ", ".join(found)
            self.trail.append(f"{name} guessed as {what} from its name")
        return found

    def _binding(self, scope, name, pos):
        """The value of the last binding of `name` in `scope` before `pos`."""
        best, best_pos = None, None
        for node in _scope_nodes(scope):
            value, done = None, None
            if isinstance(node, ast.Assign):
                for target in node.targets:
                    value = value or _pick(target, name, node.value)
                done = _end(node)
            elif isinstance(node, (ast.AnnAssign, ast.NamedExpr)) and node.value is not None:
                value, done = _pick(node.target, name, node.value), _end(node)
            elif isinstance(node, (ast.For, ast.AsyncFor)):
                value, done = _pick(node.target, name, node.iter, iterating=True), _end(node.iter)
            elif isinstance(node, ast.comprehension):
                # Comprehension variables only exist inside the comprehension.
                if self._inside(self.target, self.parents.get(node)):
                    value, done = _pick(node.target, name, node.iter, iterating=True), _end(node.iter)
            if value is not None and done <= pos and (best_pos is None or done > best_pos):
                best, best_pos = value, done
        return best

    def _is_param(self, scope, name):
        if not isinstance(scope, SCOPES):
            return False
        args = scope.args
        params = args.posonlyargs + args.args + args.kwonlyargs + [args.vararg, args.kwarg]
        return any(p is not None and p.arg == name for p in params)

    def _annotation(self, scope, name):
        args = scope.args
        for param in args.posonlyargs + args.args + args.kwonlyargs:
            if param.arg == name and param.annotation is not None:
                annotation = param.annotation
                if isinstance(annotation, ast.Subscript):  # list[Sale]
                    annotation = annotation.slice
                class_name = _str(annotation) or _base_name(annotation)
                found = [c["model"] for c in self.index.classes.get(class_name, []) if c["model"]]
                if found:
                    self.trail.append(f"{name}: {class_name} is {found[0]}")
                    return found[:1]
        return []

    def _stored(self, node):
        """The model for a name being assigned to, like `party` in `party = self.party`
        or a field definition in a class body."""
        stmt = self.parents.get(node)
        while stmt is not None and not isinstance(stmt, (ast.stmt, ast.comprehension)):
            stmt = self.parents.get(stmt)
        in_class_body = self.cls is not None and stmt in self.cls.body
        field = _field_info(stmt.value) if isinstance(stmt, ast.Assign) and in_class_body else None
        if field is not None:
            target = self.index.target_of(field)
            if target:
                return [target]
            kind = self.index.expand(field)["kind"]
            self.failure = f"{node.id} is a {kind} field, not a link to another model"
            return []
        if isinstance(stmt, ast.Assign):
            for target in stmt.targets:
                value = _pick(target, node.id, stmt.value)
                if value is not None:
                    return self.resolve(value) or self._guess(node.id)
        if isinstance(stmt, (ast.AnnAssign, ast.NamedExpr)) and stmt.value is not None:
            return self.resolve(stmt.value) or self._guess(node.id)
        if isinstance(stmt, (ast.For, ast.AsyncFor, ast.comprehension)):
            value = _pick(stmt.target, node.id, stmt.iter, iterating=True)
            return self.resolve(value) or self._guess(node.id)
        return self._guess(node.id)

    # -- entry points --------------------------------------------------------

    def run(self, mode):
        node = self.target
        if node is None:
            return _fail("Put the cursor on a name, an attribute like purchase.lines, or a model name")
        if mode == "member":
            return self._member(node)

        if isinstance(node, ast.arg):
            if node.arg in ("self", "cls"):
                models = self._self_models()
            else:
                function = self._enclosing(node, SCOPES)
                models = self._annotation(function, node.arg) or self._guess(node.arg)
        elif isinstance(node, ast.Constant):
            if _str(node) not in self.index.models:
                return _fail(f"{node.value!r} is not a model name")
            models = [node.value]
        elif isinstance(node, ast.Name) and isinstance(node.ctx, ast.Store):
            models = self._stored(node)
        else:
            models = self.resolve(node)

        if not models:
            return _fail(self.failure or f"Couldn't work out a model for {ast.unparse(node)}")
        return self._answer(models, self.index.model_locations(models))

    def _member(self, node):
        if not isinstance(node, ast.Attribute):
            return _fail("gM works on a field or method access, like purchase.lines or sale.process")
        models = self.resolve(node.value)
        if not models:
            return _fail(self.failure or f"Couldn't work out a model for {ast.unparse(node.value)}")
        locations = []
        for model in models:
            locations += self.index.member_locations(model, node.attr)
        if not locations:
            return _fail(f"No field or method called {node.attr} on {', '.join(models)}")
        return self._answer(models, locations, label=f"{node.attr} on {', '.join(models)}")

    def _answer(self, models, locations, label=None):
        if not locations:
            return _fail(f"{', '.join(models)} isn't defined under fulfil/ or fulfilio/")
        label = label or ", ".join(models)
        trail = list(dict.fromkeys(self.trail))
        note = "  →  ".join(trail)
        if self.guessed:
            note += "  (a guess)"
        return {
            "ok": True,
            "label": label,
            "locations": locations,
            "note": note,
            "title": "Fulfil: " + label,
        }


def main(argv):
    command, root, cache_dir = argv[1], argv[2], argv[3]
    index = Index(root, cache_dir)
    if command == "models":
        return {"ok": True, "models": sorted(index.models)}
    if command == "goto":
        model = argv[4]
        if model not in index.models:
            return _fail(f"No model called {model}")
        return {
            "ok": True,
            "label": model,
            "locations": index.model_locations([model]),
            "note": "",
            "title": "Fulfil: " + model,
        }
    if command == "resolve":
        path, line, col, mode = argv[4], int(argv[5]), int(argv[6]), argv[7]
        try:
            tree = ast.parse(sys.stdin.buffer.read(), path)
        except SyntaxError as exc:
            return _fail(f"Can't read this file: syntax error on line {exc.lineno}")
        return Resolver(index, tree, line, col).run(mode)
    return _fail(f"Unknown command {command}")


if __name__ == "__main__":
    try:
        result = main(sys.argv)
    except Exception as exc:  # report it in Neovim instead of a bare traceback
        traceback.print_exc()
        result = _fail(f"fulfil-nav crashed: {exc!r}")
    print(json.dumps(result))
