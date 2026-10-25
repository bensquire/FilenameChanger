.PHONY: test lint format bundle release clean

# The engine is light, so a debug test run is fine and fast; release is
# available for parity with CI if a timing-sensitive test is ever added.
test:
	swift test

lint:
	swift format lint --strict --recursive Sources Tests Package.swift

format:
	swift format --in-place --recursive Sources Tests Package.swift

bundle:
	./bundle.sh

release:
	./release.sh

clean:
	swift package clean && rm -rf FilenameChanger.app FilenameChanger.dmg dist
