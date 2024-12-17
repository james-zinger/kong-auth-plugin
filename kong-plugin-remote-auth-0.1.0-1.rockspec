local plugin_name = "remote-auth"
local package_name = "kong-plugin-" .. plugin_name
local package_version = "0.1.0"
local rockspec_revision = "1"

local github_account_name = "james-zinger"
local github_repo_name = "kong-auth-plugin"
local git_checkout = package_version == "dev" and "master" or package_version


package = package_name
version = package_version .. "-" .. rockspec_revision
supported_platforms = { "linux", "macosx" }
source = {
  url = "git+https://github.com/" .. github_account_name .. "/" .. github_repo_name .. ".git",
  branch = git_checkout,
}


description = {
  summary = "Kong auth plugin to demonstrate a custom authentication plugin via remote server.",
  homepage = "https://" .. github_account_name .. ".github.io/" .. github_repo_name,
  license = "Apache 2.0",
}


dependencies = {
}


build = {
  type = "builtin",
  modules = {
    -- TODO: add any additional code files added to the plugin
    ["kong.plugins." .. plugin_name .. ".handler"] = "kong/plugins/" .. plugin_name .. "/handler.lua",
    ["kong.plugins." .. plugin_name .. ".schema"] = "kong/plugins/" .. plugin_name .. "/schema.lua",
    ["kong.plugins." .. plugin_name .. ".auth"] = "kong/plugins/" .. plugin_name .. "/auth.lua",
  }
}
