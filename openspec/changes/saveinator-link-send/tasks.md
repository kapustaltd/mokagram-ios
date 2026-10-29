## 1. Link handling

- [x] 1.1 Read Desktop `SupportedHost`, `Normalized`, `PlatformName`, the API request/response shape and error handling
- [x] 1.2 Implement the link parser in MokoCore and unit-test supported/unsupported/trailing-punctuation/subdomain cases

## 2. Client

- [x] 2.1 Implement the Saveinator API client (request, progress, cancel, temp-file streaming); key supplied via config, not hard-coded in source
- [x] 2.2 Register the `saveinator.enabled` setting (default on) and its strings in the settings UI

## 3. Send flow

- [x] 3.1 Hook the chat text send path: when handled, clear the field and keep reply/silent/schedule/thread options
- [x] 3.2 Choice sheet (send as text / what to download / max quality)
- [x] 3.3 Progress, error, cancel and restore-text-on-failure
- [x] 3.4 Send the downloaded file through the normal media send path

## 4. Verification

- [ ] 4.1 Simulator: lone supported link, link with text, unsupported host, setting off, failure
- [x] 4.2 Message-context-menu action: confirmed by the user and implemented ("Скачать по ссылке" on a message with a supported url/textUrl link, and on the long-press menu of the link itself; the files go to the current chat and the input field is untouched)
- [ ] 4.3 Simulator: the new actions (message menu, link menu, setting off / no key hides them)
