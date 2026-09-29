const { test, describe } = require("node:test");
const assert = require("node:assert/strict");

// The naive redirect logic that failed:
function naiveRedirect(currentHref, targetFile, hash) {
  return new URL(targetFile + (hash || ""), currentHref).href;
}

// The robust redirect logic to implement:
function getRedirectUrl(currentHref, targetFile, hash = "") {
  const url = new URL(currentHref);
  let pathname = url.pathname;
  if (pathname.endsWith(".html")) {
    pathname = pathname.substring(0, pathname.lastIndexOf("/") + 1);
  } else if (!pathname.endsWith("/")) {
    pathname = pathname + "/";
  }
  url.pathname = pathname + targetFile;
  url.hash = hash || url.hash || "";
  return url.href;
}

describe("Language Redirect Logic", () => {
  test("naive implementation fails on URL without trailing slash", () => {
    const url = naiveRedirect("https://benwu232.github.io/PhantomKnob", "index_zh.html");
    // Naive resolves to root domain: https://benwu232.github.io/index_zh.html
    assert.equal(url, "https://benwu232.github.io/index_zh.html");
  });

  test("robust implementation preserves directory on URL without trailing slash", () => {
    const url = getRedirectUrl("https://benwu232.github.io/PhantomKnob", "index_zh.html");
    assert.equal(url, "https://benwu232.github.io/PhantomKnob/index_zh.html");
  });

  test("robust implementation works with trailing slash", () => {
    const url = getRedirectUrl("https://benwu232.github.io/PhantomKnob/", "index_zh.html");
    assert.equal(url, "https://benwu232.github.io/PhantomKnob/index_zh.html");
  });

  test("robust implementation works with index.html in path", () => {
    const url = getRedirectUrl("https://benwu232.github.io/PhantomKnob/index.html", "index_zh.html");
    assert.equal(url, "https://benwu232.github.io/PhantomKnob/index_zh.html");
  });

  test("robust implementation preserves hash and query params", () => {
    const url = getRedirectUrl("https://benwu232.github.io/PhantomKnob?source=app", "index_zh.html", "#pricing");
    assert.equal(url, "https://benwu232.github.io/PhantomKnob/index_zh.html?source=app#pricing");
  });
});
