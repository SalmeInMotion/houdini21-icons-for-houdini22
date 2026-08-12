"""Run inside graphical Houdini after the `waitforui` command-line token."""

import json
import os
import traceback

import hou


ICON_NAMES = (
    "BUTTONS_add",            # changed in 22
    "TOOLS_select",           # changed in 22
    "TOOLS_view",             # main viewport toolbar
    "TOOLS_move",             # main viewport toolbar
    "TOOLS_rotate",           # main viewport toolbar
    "TOOLS_scale",            # main viewport toolbar
    "TOOLS_handles",          # main viewport toolbar
    "PLAYBAR_play_forward",   # changed in 22
    "SOP_convertvdb",         # changed in 22
    "BUTTONS_action",         # common and unchanged
    "BUTTONS_3d_view",        # new in 22
)

ICON_SIZES = (16, 20, 24, 32, 64)


def main():
    output_dir = os.environ["HOUDINI_ICON_TEST_OUTPUT"]
    os.makedirs(output_dir, exist_ok=True)
    result = {"houdini": hou.applicationVersionString(), "icons": {}}

    for name in ICON_NAMES:
        result["icons"][name] = {}
        for size in ICON_SIZES:
            try:
                icon = hou.qt.Icon(name, size, size)
                pixmap = icon.pixmap(size, size)
                destination = os.path.join(output_dir, f"{name}_{size}.png")
                saved = pixmap.save(destination, "PNG")
                result["icons"][name][str(size)] = {
                    "saved": bool(saved),
                    "isNull": pixmap.isNull(),
                    "width": pixmap.width(),
                    "height": pixmap.height(),
                }
            except hou.OperationFailed as error:
                result["icons"][name][str(size)] = {
                    "missing": True,
                    "error": str(error),
                }

    with open(os.path.join(output_dir, "result.json"), "w", encoding="utf-8") as stream:
        json.dump(result, stream, indent=2)


try:
    main()
    hou.exit(0, suppress_save_prompt=True)
except SystemExit:
    raise
except Exception:
    output_dir = os.environ.get("HOUDINI_ICON_TEST_OUTPUT")
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)
        with open(os.path.join(output_dir, "error.txt"), "w", encoding="utf-8") as stream:
            stream.write(traceback.format_exc())
    hou.exit(1, suppress_save_prompt=True)
