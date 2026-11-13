"""Kök dizindeki dosya/klasör adlarından araç tespiti (docs/metrikler.md "Teknoloji").

Yalnızca adlara bakılır; dosya içeriği okunmaz. Adlar saklanmaz, yalnız bulunan araç adı.
"""

# Tam ad eşleşmesi (küçük harfe çevrilmiş) -> araç adı
EXACT = {
    "package.json": "Node.js (npm)",
    "yarn.lock": "Yarn",
    "pnpm-lock.yaml": "pnpm",
    "tsconfig.json": "TypeScript",
    "requirements.txt": "pip",
    "pyproject.toml": "pyproject (Python)",
    "pipfile": "Pipenv",
    "poetry.lock": "Poetry",
    "setup.py": "setuptools",
    "pytest.ini": "pytest",
    "alembic.ini": "Alembic",
    "dockerfile": "Docker",
    "docker-compose.yml": "Docker Compose",
    "docker-compose.yaml": "Docker Compose",
    "compose.yml": "Docker Compose",
    "compose.yaml": "Docker Compose",
    "pubspec.yaml": "Flutter/Dart (pub)",
    "go.mod": "Go modules",
    "cargo.toml": "Cargo (Rust)",
    "pom.xml": "Maven",
    "build.gradle": "Gradle",
    "build.gradle.kts": "Gradle",
    "makefile": "Make",
    "cmakelists.txt": "CMake",
    "gemfile": "Bundler (Ruby)",
    "composer.json": "Composer (PHP)",
    ".gitlab-ci.yml": "GitLab CI",
    ".travis.yml": "Travis CI",
    ".pre-commit-config.yaml": "pre-commit",
    ".prettierrc": "Prettier",
    "netlify.toml": "Netlify",
    "vercel.json": "Vercel",
}

# Önek eşleşmesi (ör. vite.config.ts, .eslintrc.json, jest.config.js)
PREFIX = {
    "vite.config.": "Vite",
    "jest.config.": "Jest",
    ".eslintrc": "ESLint",
    "eslint.config.": "ESLint",
    ".prettierrc.": "Prettier",
    "next.config.": "Next.js",
    "tailwind.config.": "Tailwind CSS",
}


def detect_tools(root_names: list[str], has_workflows: bool = False) -> list[str]:
    """Kök dizindeki adlardan araç listesi (alfabetik, tekrarsız)."""
    found: set[str] = set()
    for name in root_names:
        n = name.lower()
        if n in EXACT:
            found.add(EXACT[n])
            continue
        for prefix, tool in PREFIX.items():
            if n.startswith(prefix):
                found.add(tool)
                break
    if has_workflows:
        found.add("GitHub Actions")
    return sorted(found)
