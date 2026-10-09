const { test, describe } = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");

const ROOT_DIR = path.resolve(__dirname, "..");

// Helper to resolve language
function resolveLanguage({ urlParam, storedLang, navLang }) {
  if (urlParam === "zh" || urlParam === "en") return urlParam;
  if (storedLang === "zh" || storedLang === "en") return storedLang;
  if (navLang && typeof navLang === "string" && navLang.toLowerCase().startsWith("zh")) return "zh";
  return "en";
}

describe("Activation i18n logic", () => {
  test("resolveLanguage honors URL param first", () => {
    assert.equal(resolveLanguage({ urlParam: "en", storedLang: "zh", navLang: "zh-CN" }), "en");
    assert.equal(resolveLanguage({ urlParam: "zh", storedLang: "en", navLang: "en-US" }), "zh");
  });

  test("resolveLanguage honors localStorage if URL param not provided", () => {
    assert.equal(resolveLanguage({ storedLang: "zh", navLang: "en-US" }), "zh");
    assert.equal(resolveLanguage({ storedLang: "en", navLang: "zh-CN" }), "en");
  });

  test("resolveLanguage detects browser language if no storage", () => {
    assert.equal(resolveLanguage({ navLang: "zh-CN" }), "zh");
    assert.equal(resolveLanguage({ navLang: "zh-TW" }), "zh");
    assert.equal(resolveLanguage({ navLang: "en-US" }), "en");
    assert.equal(resolveLanguage({ navLang: "ja" }), "en");
  });

  test("resolveLanguage defaults to en if empty", () => {
    assert.equal(resolveLanguage({}), "en");
  });

  test("activate.html contains bilingual support and language switch", () => {
    const content = fs.readFileSync(path.join(ROOT_DIR, "activate.html"), "utf-8");
    assert.ok(content.includes("lang-toggle") || content.includes("lang-btn") || content.includes("toggleLang"), "activate.html must have language toggle");
    assert.ok(content.includes("Launching PhantomKnob Activation") || content.includes("Open & Activate App"), "activate.html must include English strings");
    assert.ok(content.includes("正在启动 PhantomKnob 激活") || content.includes("打开并激活 App"), "activate.html must include Chinese strings");
    assert.ok(content.includes("phantomknob232@gmail.com"), "activate.html must include support email");
  });
});

describe("Legal pages bilingual files and links", () => {
  const legalFiles = [
    { en: "privacy.html", zh: "privacy_zh.html" },
    { terms: "terms.html", zh: "terms_zh.html" },
    { refund: "refund.html", zh: "refund_zh.html" }
  ];

  test("Chinese legal pages exist", () => {
    assert.ok(fs.existsSync(path.join(ROOT_DIR, "privacy_zh.html")), "privacy_zh.html must exist");
    assert.ok(fs.existsSync(path.join(ROOT_DIR, "terms_zh.html")), "terms_zh.html must exist");
    assert.ok(fs.existsSync(path.join(ROOT_DIR, "refund_zh.html")), "refund_zh.html must exist");
  });

  test("index_zh.html points to Chinese legal pages", () => {
    const indexZh = fs.readFileSync(path.join(ROOT_DIR, "index_zh.html"), "utf-8");
    assert.ok(indexZh.includes('href="privacy_zh.html"'), "index_zh.html must link to privacy_zh.html");
    assert.ok(indexZh.includes('href="terms_zh.html"'), "index_zh.html must link to terms_zh.html");
    assert.ok(indexZh.includes('href="refund_zh.html"'), "index_zh.html must link to refund_zh.html");
    assert.ok(!indexZh.includes('href="privacy.html"'), "index_zh.html must not link to English privacy.html");
    assert.ok(!indexZh.includes('href="terms.html"'), "index_zh.html must not link to English terms.html");
    assert.ok(!indexZh.includes('href="refund.html"'), "index_zh.html must not link to English refund.html");
  });

  test("Legal pages have streamlined header and back links", () => {
    const privacyEn = fs.readFileSync(path.join(ROOT_DIR, "privacy.html"), "utf-8");
    const privacyZh = fs.readFileSync(path.join(ROOT_DIR, "privacy_zh.html"), "utf-8");

    assert.ok(privacyEn.includes("privacy_zh.html"), "privacy.html must link to privacy_zh.html");
    assert.ok(privacyEn.includes('href="index.html"'), "privacy.html must link back to index.html");

    assert.ok(privacyZh.includes("privacy.html"), "privacy_zh.html must link to privacy.html");
    assert.ok(privacyZh.includes('href="index_zh.html"'), "privacy_zh.html must link back to index_zh.html");
  });
});

describe("Index pages preference symmetry", () => {
  test("index.html records preference as English", () => {
    const indexEn = fs.readFileSync(path.join(ROOT_DIR, "index.html"), "utf-8");
    assert.ok(
      indexEn.includes('localStorage.setItem("pk_preferred_lang", "en")'),
      "index.html must set pk_preferred_lang to en on load or in script"
    );
  });

  test("index_zh.html records preference as Chinese", () => {
    const indexZh = fs.readFileSync(path.join(ROOT_DIR, "index_zh.html"), "utf-8");
    assert.ok(
      indexZh.includes('localStorage.setItem("pk_preferred_lang", "zh")'),
      "index_zh.html must set pk_preferred_lang to zh on load"
    );
  });
});
