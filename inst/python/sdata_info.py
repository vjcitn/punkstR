### Print a JSON summary of a SpatialData (zarr) store, for punkstR::sdata_info().
import sys
import json
import argparse


def summarize(path, points_key=None):
    import spatialdata as sd
    from spatialdata.transformations import get_transformation

    sdata = sd.read_zarr(path)
    out = {"spatialdata_version": sd.__version__, "points": {}, "images": {},
           "shapes": list(sdata.shapes), "tables": list(sdata.tables)}
    for key, pts in sdata.points.items():
        info = {"columns": [str(c) for c in pts.columns],
                "attrs": {k: v for k, v in pts.attrs.get("spatialdata_attrs", {}).items()
                          if isinstance(v, (str, int, float, type(None)))}}
        if points_key is None or key == points_key:
            info["rows"] = int(len(pts))
            info["max_x"] = float(pts["x"].max().compute())
            info["max_y"] = float(pts["y"].max().compute())
        tr = {}
        for cs, t in get_transformation(pts, get_all=True).items():
            entry = {"type": type(t).__name__, "repr": repr(t)}
            if hasattr(t, "scale"):
                entry["scale"] = [float(s) for s in t.scale]
            tr[cs] = entry
        info["transformations"] = tr
        out["points"][key] = info
    for key, img in sdata.images.items():
        try:
            a = img["scale0"]["image"]
        except Exception:
            a = img
        out["images"][key] = {"sizes": {str(k): int(v) for k, v in dict(a.sizes).items()}}
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser(prog="sdata_info")
    p.add_argument("--sdata", required=True)
    p.add_argument("--points-key", default=None)
    p.add_argument("--out", required=True)
    a = p.parse_args(sys.argv[1:])
    with open(a.out, "w") as fh:
        json.dump(summarize(a.sdata, a.points_key), fh)
