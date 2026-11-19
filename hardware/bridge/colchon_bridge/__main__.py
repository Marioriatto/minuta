from __future__ import annotations

import argparse
import logging
import sys
import time
from pathlib import Path

from . import protocol as p
from .api import DeviceApi
from .bridge import Bridge
from .calibrate import calibrate
from .config import ConfigError, load_config
from .links import FakeLink, SerialLink


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(prog="colchon_bridge", description=__doc__)
    ap.add_argument("--config", type=Path, default=Path("bridge.toml"))
    ap.add_argument("-v", "--verbose", action="store_true")
    sub = ap.add_subparsers(dest="cmd")
    run = sub.add_parser("run", help="ejecuta el puente (por defecto)")
    run.add_argument("--simulate", choices=["normal", "alarm"],
                     help="usa un Arduino simulado en vez del puerto serie")
    cal = sub.add_parser("calibrate", help="calibra la balanza con un peso conocido")
    cal.add_argument("--known-kg", type=float, required=True)
    args = ap.parse_args(argv)

    logging.basicConfig(level=logging.DEBUG if args.verbose else logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s")
    try:
        cfg = load_config(args.config)
    except ConfigError as e:
        print(f"Configuración inválida: {e}", file=sys.stderr)
        return 2

    simulate = getattr(args, "simulate", None)
    if args.cmd == "calibrate":
        link = SerialLink(cfg.serial_port, cfg.baud)
        try:
            time.sleep(2)  # el UNO se reinicia al abrir el puerto
            factor = calibrate(link, args.known_kg)
            print(f"Listo. Factor de escala {factor:.4f} guardado en el Arduino.")
        finally:
            link.close()
        return 0

    link = FakeLink(simulate) if simulate else SerialLink(cfg.serial_port, cfg.baud)
    apis = {n: DeviceApi(cfg.base_url, t, cfg.timeout_s) for n, t in cfg.tokens.items()}
    bridge = Bridge(link, apis, cfg.tuning, time.time)
    logging.getLogger("colchon.bridge").info(
        "Puente iniciado (%s). Ctrl+C para salir.", "simulado" if simulate else cfg.serial_port)
    try:
        time.sleep(0 if simulate else 2)
        link.write(p.CMD_PING)
        bridge.poll(force=True)
        while True:
            bridge.step()
            time.sleep(0.2)
    except KeyboardInterrupt:
        bridge.flush(force=True)
        return 0
    except ConnectionError as e:
        print(e, file=sys.stderr)
        return 1
    finally:
        link.close()


if __name__ == "__main__":
    sys.exit(main())
