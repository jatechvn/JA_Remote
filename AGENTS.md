# AGENTS.md - Dart/Flutter sample

Huong dan nen cho Codex va cac coding agent khi lam trong sample Flutter/Dart nay. Giu file nay ngan vi Codex doc no truoc moi task; dua kien truc chi tiet vao `docs/AI_CONTEXT.md` va trang thai dang lam vao `docs/AI_HANDOFF.md`.

## Cach lam viec

- Tra loi Johnny bang tieng Viet mac dinh; technical English giu nguyen khi ro hon.
- Neu task can hieu project, doc `docs/AI_CONTEXT.md` truoc. Neu tiep tuc viec dang do, doc them `docs/AI_HANDOFF.md`.
- Voi task nho da co scope ro, chi doc file lien quan va dependency truc tiep. Mo them file khi can bang chung cu the.
- Neu task lien quan skill/workflow, kiem tra custom `.claude/skills/` truoc, sau do dung ban Codex tuong ung trong `.codex/skills/` khi co.
- Chon cach don gian hop ly cho chi tiet rui ro thap. Chi hoi lai khi quyet dinh anh huong architecture, compatibility, release, hoac hanh vi nguoi dung thay duoc.

## Context du an

- Root nay la sample/template cho JA-Tech System Flutter/Dart, khong phai mot app production duy nhat.
- `UI_DESIGN_Sample.html` la HTML UI sample lon; can giu visual khi toi uu.
- `flutter_ui_template/` va `flutter_bubble_ui_template/` la template Flutter con.
- `skills/`, `.claude/skills/`, `.agents/skills/`, `.codex/skills/` la bo skill mau de dong bo giua agent environments.

## Constraints

- Tao patch nho nhat co the giai quyet dung muc tieu.
- Giu architecture/state-management hien co; khong doi framework/pattern neu user khong yeu cau.
- Khong refactor file khong lien quan.
- Khong them dependency neu khong can thiet; neu can, neu ly do va kiem tra tinh on dinh.
- Khong chay `flutter clean`, xoa generated/build output, xoa backup, hoac lenh pha huy du lieu khi chua co xac nhan ro.
- Null safety can than; tranh ep `!` neu chua co invariant ro.
- Voi UI, giu visual structure hien co tru khi user yeu cau redesign.

## Verification

- Chay check hep nhat truoc, dung voi pham vi thay doi.
- Sau thay doi Dart/Flutter code: chay `dart format .`, `dart analyze` hoac `flutter analyze`, va `flutter test` neu project co test lien quan.
- Sau thay doi HTML/CSS/JS: chay static parse/check lien quan; chi noi da verify visual/FPS khi da mo browser/Playwright hoac cong cu tuong duong.
- Neu PATH wrapper hoac mapped drive treo, dung tool SDK truc tiep neu co va noi ro gioi han verification.

## Response

- Bao cao ngan: root cause/decision chinh, file da doi, verification, van de con lai neu co.
- Khong giai thich tung dong code moi viet neu user khong yeu cau.
- Cuoi cau tra loi them mot goi y prompt tiep theo kem skill lien quan.
