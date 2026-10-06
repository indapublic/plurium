#!/usr/bin/env python3
"""Runs Chromium's sign_chrome.py without its Gatekeeper check right after
signing.

On current macOS `spctl --assess` rejects a Developer ID app ("Unnotarized
Developer ID") until it is notarized, and the signing pipeline notarizes only
after that check. release.sh runs spctl on the notarized app instead.

Usage: sign.py <out>/"Chromium Packaging" <sign_chrome.py arguments...>
"""

import sys

if __name__ == '__main__':
    sys.path.append(sys.argv[1])
    import signing.config
    import signing.driver

    signing.config.CodeSignConfig.run_spctl_assess = property(lambda self: False)
    signing.driver.main(sys.argv[2:])
