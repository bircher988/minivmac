# Mini vMac in the browser (branch `browser`)

This branch is the source of the Mini vMac builds that run in the browser on
[bircher.ai](https://bircher.ai/emulator/): a Macintosh 128K, 512K and Plus compiled to
WebAssembly with Emscripten. It is Mini vMac 37.03 from
[github.com/minivmac/minivmac](https://github.com/minivmac/minivmac) (commit 05129c7)
with the changes below. Mini vMac is free software under the GNU General Public License,
version 2 (`COPYING.txt`).

## Build

    ./build_browser.sh                 # all three: out/browser/MinivMac-{128k,512k,plus}.js + .wasm
    ./build_browser.sh 512k            # one machine
    ./build_browser.sh -o <dir> plus

Needs the Emscripten SDK (`~/emsdk`, or `EMSDK_ENV=.../emsdk_env.sh`). The machines:
`-m 128K -mem 128K`, `-m 128K -mem 512K` and `-m Plus -mem 2M`, each with the speed fixed
at 1x, sound on and the emulator's own magnify off.

## Changes

- **`wasm_insert_disk(path)`** (`src/OSGLUSDL.c`): inserts a disk image from Emscripten's
  in-memory file system into a free drive while the Mac runs - what a file dropped onto
  the native window does (SDL_DROPFILE, which SDL does not deliver in the browser).
  Returns 1 when the disk went into a drive, 0 when it did not (no free drive, or not a
  disk image).
- **`wasm_set_grab(on)` / `wasm_get_grab()`** (`src/OSGLUSDL.c`): relative mouse mode for
  games that read raw mouse movement, without the emulator's own full screen (which
  recreates the SDL window and does not survive that in the browser).
- **MOVEP** (`src/MINEM68K.c`): the 16-bit displacement of `MOVEP (d16,An)` is sign
  extended, as on a real 68000; before, every negative displacement addressed 64 KB too
  high.
- **VIA register 15** (`src/VIAEMDEV.c`): only register 1 (ORA with handshake) clears the
  CA1/CA2 interrupt flags. Register 15 is the one the ROM and the drivers use; clearing
  CA1 there lost vertical blanking interrupts (the clock ran slow under LocalTalk
  traffic).
- **LocalTalk** (`src/SCCEMDEV.c`, `src/PROGMAIN.c`, `src/OSGLUSDL.c`): the SCC's
  Break/Abort external/status interrupt that the LocalTalk driver waits for, and a check
  for received frames on every sub-tick. Only compiled with `-lt` (not in the browser
  builds).

## What the page provides

- `Module.arguments`: `['-r', '/vMac.ROM', '<disk>', ...]`; the ROM and the disks are
  written into the file system with `FS.writeFile` in `Module.preRun`.
- The screen: `<canvas id="canvas">` (the mouse handlers are attached to
  `document.querySelector('#canvas')`), passed as `Module.canvas`.
- Disks later: `FS.writeFile(path, data)`, then
  `Module.ccall('wasm_insert_disk', 'number', ['string'], [path])`.
- Keys: Mini vMac's control mode Control-F and Control-M (full screen, magnify) recreate
  the SDL window and stop the emulator: the page keeps those two keys away from it. The
  mouse wheel becomes arrow keys; the page may keep it away too. The Command key is the
  Meta (Windows) key, Option is Alt.
