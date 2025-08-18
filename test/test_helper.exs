ExUnit.start()

# Load support files
Code.require_file("support/test_fixtures.ex", __DIR__)
Code.require_file("support/scim_compliance_helpers.ex", __DIR__)
# Code.require_file("support/storage_test_helper.ex", __DIR__)

# Ensure storage is started for tests
# ExScim.Test.StorageTestHelper.ensure_storage_started()
