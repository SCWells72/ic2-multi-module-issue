# Multi-Module (monorepos) project with Illuminated Cloud 2

- IC2 doesn't function properly if the root module of an IntelliJ project has a content root that contains salesforce submodules
- This structure is common for multi module projects, especially mono-repos
- The workaround is to remove the content root from the root module, which presents many downstream issues
  - Can't easily edit files
  - Can't use native "open file" dialogs
  - Files are not searched
  - Files are not easily tracked into VCS
  - etc

This repo is a demonstration of the issue and provides a demo video showing the issue in detail, found under [static/demo-showing-ic2-multi-module-issue.mov](static/demo-showing-ic2-multi-module-issue.mov)