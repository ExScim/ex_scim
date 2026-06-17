# Route all Req requests made during tests through Req.Test, keyed by the shared stub name.
# Each test installs its own stub via Req.Test.stub/2; tests that never call Req (filter/request/doctests) are unaffected.
Req.default_options(plug: {Req.Test, ExScimClient.Stub})

ExUnit.start()
