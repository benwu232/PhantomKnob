#!/bin/bash
# PhantomKnob End-to-End Sparkle Update Mock Test Script

TEST_PORT=8899
MOCK_DIR="/tmp/phantomknob_update_test"
mkdir -p "$MOCK_DIR"

echo "==> Setting up Mock Server at http://localhost:${TEST_PORT}/appcast.xml..."

cat <<EOF > "$MOCK_DIR/appcast.xml"
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>PhantomKnob Test Feed</title>
    <item>
      <title>Version 9.9.9</title>
      <sparkle:releaseNotesLink>https://phantomknob.com/releasenotes.html</sparkle:releaseNotesLink>
      <pubDate>Wed, 05 Aug 2026 12:00:00 +0000</pubDate>
      <enclosure url="http://localhost:${TEST_PORT}/PhantomKnob_v9.9.9.zip"
                 sparkle:version="9999"
                 sparkle:shortVersionString="9.9.9"
                 length="123456"
                 type="application/octet-stream" />
    </item>
  </channel>
</rss>
EOF

echo "==> Launching Mock HTTP Server..."
python3 -m http.server $TEST_PORT --directory "$MOCK_DIR" &
SERVER_PID=$!

trap "kill $SERVER_PID" EXIT

echo "==> Mock server running with PID $SERVER_PID."
echo "==> You can now test update check against http://localhost:${TEST_PORT}/appcast.xml"
sleep 2
