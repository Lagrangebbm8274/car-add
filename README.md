# hashiriya（china） helper

A compact SwiftUI iOS app that imports one Hashiriya China game plist, lets you perform three local edits, and exports the edited plist using the original filename:

- 修改昵称：updates both verified nickname fields.
- 增加宝石：writes the verified ObscuredPrefs `ExtraGems` value and checksum; preserves Initial/Difference values.
- 添加车辆：supports multiple rows in one operation. Each row accepts a preset (`supramkv`, `jza80fusion`, `huricane`) or a custom internal name, plus an independent quantity. Blank rows are ignored; repeated copies of the same model are supported.

## Import compatibility

The document picker accepts generic files, data files and property lists. The importer reads the selected file's bytes directly (including security-scoped Files-provider URLs), then lets Apple's PropertyListSerialization auto-detect XML or binary plist format. The original format is retained when serializing the edited dictionary. It does not rely on the filename extension or MIME label.

All three operations can be applied to the same in-memory working copy before a single export. Nickname and gem inputs are optional: leaving either field blank skips that edit. The vehicle editor starts with one blank row; use the plus button to add more model rows. Empty vehicle names are skipped. Unrelated dictionary keys are retained. The exporter suggests the exact imported filename.

## Build IPA

Upload the repository contents to the root of a GitHub repository. Open Actions → Build Hashiriya China Helper IPA → Run workflow. The workflow uploads `HashiriyaChinaHelper-IPA` as an unsigned IPA artifact. Installation still depends on the signing/TrollStore method available on the iPad.
