# Chapter title fonts

Small AngelCode **binary** BMFont packs for `story/chapter_transition.lua`.

| File | Source TTF |
| --- | --- |
| `yozai_medium.fnt` + `yozai_medium_0.png` | `codex_work/font/Yozai-Medium.ttf` |
| `xiaolai.fnt` + `xiaolai_0.png` | `codex_work/font/Xiaolai-Regular.ttf` |
| `cef_cjk.fnt` + `cef_cjk_0.png` | `codex_work/font/CEFFontsCJK-Regular.ttf` |

Charset is intentionally tiny (ASCII + `序章狩猎第一二三四五·`). Expand via:

```powershell
& "D:\Apps\Miniconda\envs\llm\python.exe" codex_work/tools/build_chapter_title_fonts.py
```

Do **not** load TTFs at runtime. Isaac `Font():Load` requires `.fnt` + atlas PNG.
