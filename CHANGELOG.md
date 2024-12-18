# Staytus Change Log

This file outlines the key changes between different revisions. The `stable`
branch will always contain the latest released version. Each version will
be tagged as appropriate.

Any version number which is suffixed by `-dev` means that it is currently
being developed and is not yet released. It is most likely you'll only ever
see this in a master branch.

## v1.4.0

* Add invisible_captcha to reduce subscriber spam
* Add a button to clean all unverified subscribers

## v1.3.5

* Upgrade underlying Rails version to 7.2

## v1.3.4

* Upgrade underlying Rails version to 6.1
* Upgrade authie to version 4
* Upgrade Ruby to 3.3

## v1.3.0

* Upgrade underlying Rails version to 5.1

## v1.2.0

* Allow services to be grouped
* Allow subscribers to be added through the admin interface

## v1.0.1

* Allow services to have a description which will be displayed on the
  default theme.
* Add API tokens to allow services to authenticate to the API.
* Add `services/all` API method - for list all services with current status.
* Add `services/info` API method - to return details about a specific API method.
* Add `services/set_status` API method - to set the status for a specific service.

## v1.0.0

* Initial Release
