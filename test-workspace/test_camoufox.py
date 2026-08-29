"""
Camoufox Anti-Detect Browser Automation Example
Works seamlessly inside the isolated Docker sandbox with Playwright API.
"""

from camoufox.sync_api import Camoufox

def main():
    print("🦊 Launching Camoufox Stealth Browser...")
    with Camoufox(headless=True) as browser:
        page = browser.new_page()
        
        # Test navigation to a target site
        print("🌐 Navigating to https://httpbin.org/headers ...")
        page.goto("https://httpbin.org/headers")
        
        print("📄 Page Title:", page.title())
        print("🔍 Response Content:")
        print(page.inner_text("body"))
        
        # Take a screenshot
        page.screenshot(path="camoufox_screenshot.png")
        print("📸 Screenshot saved to camoufox_screenshot.png")

if __name__ == "__main__":
    main()
