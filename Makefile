
install:
	swift build -c release
	cp -f .build/release/CLI /usr/local/bin/chill
