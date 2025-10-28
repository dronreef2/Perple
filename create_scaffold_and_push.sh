#!/usr/bin/env bash
set -euo pipefail

# create_scaffold_and_push.sh
# This script creates the project scaffold files for the Perplexity project
# (pyproject.toml, package files, docs, CI, etc.), commits them and pushes to main.
# Run this locally from the repository root. It will create files and push them to origin/main.

cat > pyproject.toml <<'EOF'
[build-system]
requires = ["setuptools", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "perplexity"
version = "0.0.1"
description = "Perplexity API client with Emailnator integration and browser drivers (Selenium/Playwright)"
authors = [
  { name="Your Name", email="you@example.com" }
]
readme = "README.md"
requires-python = ">=3.9"
dependencies = [
  "requests>=2.28",
  "aiohttp>=3.8",
  "selenium>=4.8",
  "playwright>=1.30",
]

[project.optional-dependencies]
dev = [
  "pytest>=7.0",
  "pytest-asyncio>=0.20",
  "pytest-mock",
  "flake8",
  "black"
]
EOF

cat > README.md <<'EOF'
# Perplexity Python client

Perplexity client com integração Emailnator e drivers para automação (Selenium/Playwright).

Instalação (modo de desenvolvimento):

```bash
python -m venv .venv
source .venv/bin/activate     # Linux / macOS
.venv\Scripts\activate        # Windows

pip install -U pip setuptools wheel
pip install -e .
```

Executando os testes (CI usa pytest):

```bash
pip install -r requirements-dev.txt
pytest -q
```

Uso básico (sincrono):

```python
from perplexity import PerplexityClient

client = PerplexityClient(base_url="https://api.perplexity.example")
resp = client.search("Qual é a capital de Portugal?")
print(resp)
```

Geração de conta com Emailnator:

```python
from perplexity.integrations.emailnator import EmailnatorClient
email_client = EmailnatorClient(api_key="YOUR_KEY")
acc = email_client.generate_account()
print(acc)  # dicionário com endereço e credenciais/token
```

Driver de automação (Playwright):

```python
from perplexity.driver import PlaywrightDriver

drv = PlaywrightDriver(headless=True, user_data_dir="~/.config/perplexity_profile")
with drv.launch() as pw:
    page = pw.new_page()
    page.goto("https://perplexity.ai")
    # interagir...
```

Cookie-based auth:
- Veja docs/cookie_extraction.md para instruções de extrair cookies do navegador e carregar no cliente.
EOF

cat > .gitignore <<'EOF'
__pycache__/
.venv/
dist/
build/
*.egg-info
.env
.env.local
.coverage
.vscode/
.idea/
.playwright/
nodes_modules/
EOF

mkdir -p docs
cat > docs/emailnator.md <<'EOF'
# Emailnator integration

Este documento descreve como usar a integração de Emailnator incluída em perplexity.integrations.emailnator.

1. Configure a variável de ambiente com sua API key:
```bash
echo "export EMAILNATOR_API_KEY=your_api_key_here"
```

2. No código:
```python
from perplexity.integrations.emailnator import EmailnatorClient
client = EmailnatorClient(api_key=os.environ["EMAILNATOR_API_KEY"], base_url="https://api.emailnator.example")
inbox = client.generate_account(name_hint="perplexity-test")
print(inbox)
```

3. Consultar mensagens:
```python
msgs = client.get_messages(inbox_id=inbox["id"])
```

Notas:
- Substitua base_url e endpoints conforme a documentação oficial do provedor.
- Não comite chaves para o repositório. Use secrets no CI e variáveis de ambiente em produção.
- Adicione retries/backoff se o provedor tiver rate limits.
EOF

cat > docs/cookie_extraction.md <<'EOF'
# Extração e uso de cookies para autenticação

Opções para extrair cookies a partir do navegador:

1. Via DevTools (Chrome/Edge)
 - Abra DevTools (F12) -> Application -> Cookies.
 - Copie manualmente os cookies relevantes e salve em JSON (nome/valor/domain/path).

2. Via Selenium (automatizado)
 - Use Selenium para fazer login, então execute:
```python
cookies = driver.get_cookies()
# converta para dict name->value:
cookie_dict = {c["name"]: c["value"] for c in cookies}
```

3. Ferramentas de export (extensões)
 - EditThisCookie e outras extensões permitem exportar cookies em formato JSON.

Como carregar no PerplexityClient (sync):
```python
from perplexity import PerplexityClient
cookie_dict = {"_p": "cookievalue", "session": "abc"}
client = PerplexityClient(cookie_or_session=cookie_dict)
```

Como carregar num aiohttp.CookieJar (async):
```python
import aiohttp
jar = aiohttp.CookieJar()
jar.update_cookies({"_p": "cookievalue"})
client = AsyncPerplexityClient(cookie_jar=jar)
```

Segurança:
 - Nunca versionar cookies. Trate-os como credenciais.
 - Use profiles / user_data_dir para usar sessões persistentes com browsers em automação.
EOF

cat > requirements-dev.txt <<'EOF'
pytest>=7.0
pytest-asyncio>=0.20
pytest-mock
playwright
selenium
requests
aiohttp
flake8
black
EOF

mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'EOF'
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    - name: Set up Python
      uses: actions/setup-python@v4
      with:
        python-version: "3.10"
    - name: Install dependencies
      run: |
        python -m pip install -U pip
        pip install -e .
        pip install -r requirements-dev.txt
    - name: Install Playwright browsers
      if: always()
      run: |
        python -m pip install playwright
        playwright install --with-deps chromium
    - name: Run tests
      env:
        PLAYWRIGHT_BROWSERS_PATH: 0
      run: |
        pytest -q
EOF

mkdir -p perplexity/integrations
cat > perplexity/__init__.py <<'EOF'
__all__ = ["PerplexityClient"]

from .client import PerplexityClient
EOF

cat > perplexity/client.py <<'EOF'
import requests
from typing import Generator, Optional, Dict, Any

from .integrations.emailnator import EmailnatorClient

class PerplexityClient:
    def __init__(self, cookie_or_session: Optional[requests.Session] = None, base_url: str = "https://api.perplexity.example"):
        self.base_url = base_url
        if isinstance(cookie_or_session, requests.Session):
            self._session = cookie_or_session
        else:
            self._session = requests.Session()
            if isinstance(cookie_or_session, dict):
                self._session.cookies.update(cookie_or_session)

        self.emailnator: EmailnatorClient | None = None

    def attach_emailnator(self, api_key: str, base_url: str = "https://api.emailnator.example"):
        self.emailnator = EmailnatorClient(api_key=api_key, base_url=base_url)

    def search(self, query: str, mode: str = "default", params: Optional[Dict[str, Any]] = None) -> Dict:
        payload = {"q": query, "mode": mode}
        if params:
            payload.update(params)
        r = self._session.post(f"{self.base_url}/search", json=payload, timeout=30)
        r.raise_for_status()
        return r.json()

    def search_stream(self, query: str) -> Generator[str, None, None]:
        with self._session.post(f"{self.base_url}/search/stream", json={"q": query}, stream=True) as r:
            r.raise_for_status()
            for chunk in r.iter_lines(decode_unicode=True):
                if chunk:
                    yield chunk.decode() if isinstance(chunk, bytes) else chunk

    def generate_emailnator_account(self) -> Dict:
        if not self.emailnator:
            raise RuntimeError("Emailnator client not attached. Call attach_emailnator(api_key, base_url).")
        return self.emailnator.generate_account()
EOF

cat > perplexity/integrations/emailnator.py <<'EOF'
import os
import requests
from typing import Dict, Optional

class EmailnatorClient:
    """
    Simple wrapper for Emailnator-like services. This is a small abstraction
    to create temporary inboxes and fetch messages.

    NOTE: endpoints and fields below are placeholders. Replace with the real
    API paths/params according to the Emailnator provider documentation.
    """

    def __init__(self, api_key: str, base_url: str = "https://api.emailnator.example"):
        self.api_key = api_key
        self.base_url = base_url
        self._session = requests.Session()
        self._session.headers.update({"Authorization": f"Bearer {self.api_key}", "User-Agent": "perplexity-client/0.0.1"})

    def generate_account(self, name_hint: Optional[str] = None) -> Dict:
        payload = {}
        if name_hint:
            payload["hint"] = name_hint
        r = self._session.post(f"{self.base_url}/inboxes", json=payload, timeout=15)
        r.raise_for_status()
        return r.json()

    def get_messages(self, inbox_id: str) -> Dict:
        r = self._session.get(f"{self.base_url}/inboxes/{inbox_id}/messages", timeout=15)
        r.raise_for_status()
        return r.json()
EOF

cat > perplexity/driver.py <<'EOF'
"""
Driver module providing two implementations:
 - SeleniumChromeDriver: controls Chrome via Selenium WebDriver
 - PlaywrightDriver: controls Chromium via Playwright (recommended for CI and modern usage)

Both drivers support:
 - user_data_dir (profile)
 - headless mode
 - remote debugging connection for Selenium (connect to an existing Chrome with --remote-debugging-port)
"""

from contextlib import contextmanager
import os
from typing import Optional

# Selenium driver
try:
    from selenium import webdriver
    from selenium.webdriver.chrome.options import Options as ChromeOptions
    from selenium.webdriver.chrome.service import Service as ChromeService
except Exception:
    webdriver = None  # selenium might not be installed in all envs

# Playwright driver
try:
    from playwright.sync_api import sync_playwright, Browser, Playwright
except Exception:
    sync_playwright = None


class SeleniumChromeDriver:
    def __init__(self, user_data_dir: Optional[str] = None, remote_debugging_port: Optional[int] = None, headless: bool = True, chrome_path: Optional[str] = None):
        if webdriver is None:
            raise RuntimeError("selenium is not installed. pip install selenium")
        options = ChromeOptions()
        if user_data_dir:
            options.add_argument(f"--user-data-dir={os.path.expanduser(user_data_dir)}")
        if remote_debugging_port:
            options.add_argument(f"--remote-debugging-port={remote_debugging_port}")
        # new headless mode flag recommended in newer chrome versions
        if headless:
            options.add_argument("--headless=new")
        self.options = options
        self.chrome_path = chrome_path

    def start(self):
        service = ChromeService(executable_path=self.chrome_path) if self.chrome_path else ChromeService()
        driver = webdriver.Chrome(service=service, options=self.options)
        return driver

    def connect_to_remote(self, remote_debugging_url: str):
        # Selenium + Chrome DevTools remote connection can be tricky; often easier to connect via CDP.
        # This is a convenience: if a Chrome process is already running with --remote-debugging-port,
        # Selenium can attach via webdriver.Chrome with proper options (e.g., debuggingAddress) depending on driver.
        raise NotImplementedError("Connecting to an existing Chrome via Selenium varies by chromedriver version. Prefer Playwright for remote debugging in CI.")


class PlaywrightDriver:
    def __init__(self, headless: bool = True, user_data_dir: Optional[str] = None, chromium_executable_path: Optional[str] = None):
        if sync_playwright is None:
            raise RuntimeError("playwright is not installed. pip install playwright")
        self._headless = headless
        self._user_data_dir = os.path.expanduser(user_data_dir) if user_data_dir else None
        self._chromium_executable_path = chromium_executable_path
        self._pw: Optional[Playwright] = None
        self._browser: Optional[Browser] = None

    @contextmanager
    def launch(self):
        """
        Context manager that launches Playwright and yields a browser object.
        Usage:
            with PlaywrightDriver(...).launch() as pw:
                page = pw.new_page()
        """
        self._pw = sync_playwright().start()
        launch_args = {"headless": self._headless}
        if self._chromium_executable_path:
            launch_args["executable_path"] = self._chromium_executable_path

        if self._user_data_dir:
            # persistent context preserves cookies and localStorage
            self._browser = self._pw.chromium.launch_persistent_context(self._user_data_dir, **launch_args)
            try:
                yield self._browser
            finally:
                self._browser.close()
                self._pw.stop()
        else:
            self._browser = self._pw.chromium.launch(**launch_args)
            try:
                page = self._browser.new_page()
                yield page
            finally:
                self._browser.close()
                self._pw.stop()
EOF

mkdir -p perplexity_async
cat > perplexity_async/__init__.py <<'EOF'
__all__ = ["AsyncPerplexityClient"]

from .async_client import AsyncPerplexityClient
EOF

cat > perplexity_async/async_client.py <<'EOF'
import aiohttp
from typing import AsyncGenerator, Optional, Dict, Any

class AsyncPerplexityClient:
    def __init__(self, cookie_jar: Optional[aiohttp.CookieJar] = None, base_url: str = "https://api.perplexity.example"):
        self.base_url = base_url
        self._cookie_jar = cookie_jar or aiohttp.CookieJar()
        self._session: Optional[aiohttp.ClientSession] = None

    async def _ensure_session(self):
        if self._session is None:
            self._session = aiohttp.ClientSession(cookie_jar=self._cookie_jar)

    async def close(self):
        if self._session:
            await self._session.close()

    async def search(self, query: str, mode: str = "default", params: Optional[Dict[str, Any]] = None) -> Dict:
        await self._ensure_session()
        payload = {"q": query, "mode": mode}
        if params:
            payload.update(params)
        async with self._session.post(f"{self.base_url}/search", json=payload) as r:
            r.raise_for_status()
            return await r.json()

    async def search_stream(self, query: str) -> AsyncGenerator[str, None]:
        await self._ensure_session()
        async with self._session.post(f"{self.base_url}/search/stream", json={"q": query}) as r:
            r.raise_for_status()
            async for chunk in r.content.iter_any():
                if chunk:
                    yield chunk.decode()
EOF

cat > LICENSE <<'EOF'
MIT License

Copyright (c) 2025 Your Name

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

THE ABOVE COPYRIGHT NOTICE AND THIS PERMISSION NOTICE SHALL BE INCLUDED IN ALL
COPIES OR SUBSTANTIAL PORTIONS OF THE SOFTWARE.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

# Stage files, commit and push to main

git add .
if git diff --staged --quiet; then
  echo "No changes to commit"
else
  git commit -m "Scaffold: package structure, Emailnator stub, drivers, CI, docs"
  echo "Pushing to origin/main..."
  git push origin main
fi

echo "Done. If the push failed, ensure you have write access and the correct remote set."