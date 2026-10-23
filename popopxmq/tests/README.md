# Running tests with coverage

1. Uncomment coverage sections in cabal.project file.
2. Add `-fhpc` to ghc-options of popopxmq-test in popopxmq.cabal file.
3. Disable (`xit`) test "should subscribe to multiple (200) subscriptions with batching", enable (comment `skip`) the next test instead.
4. Run `cabal test`.
5. Open generated coverage report in the browser.
