### Write punkst results (hexagon counts, topic probabilities, gene x topic
### loadings) into a SpatialData (zarr) store, for punkstR::sdata_writeback().
#
# Each run "<run>" adds two elements, so several runs (different topic counts,
# hexagon sizes, seeds, ...) can live side by side in one store:
#   shapes  "punkst_<run>_hexagons"  circles at the hexagon centres
#   tables  "punkst_<run>"           hexagons x genes counts; obsm["topics"]
#                                    (hexagons x K), varm["loadings"] (genes x K),
#                                    uns["punkst"] = run parameters/provenance
# The shapes carry the transformations of the source Points element when the
# hexagons are in its intrinsic coordinates, so they align with the transcripts.
import sys
import json
import argparse

import numpy as np
import pandas as pd
import scipy.sparse as sp


def _key(x, y):
    return np.char.add(np.char.add(np.round(x, 3).astype("U32"), " "),
                       np.round(y, 3).astype("U32"))


def read_hex(path, meta_path):
    with open(meta_path) as fh:
        meta = json.load(fh)
    dictionary = meta["dictionary"]
    genes = [None] * len(dictionary)
    for g, i in dictionary.items():
        genes[i] = g
    keys, xs, ys, rows, cols, vals = [], [], [], [], [], []
    with open(path) as fh:
        for r, line in enumerate(fh):
            f = line.rstrip("\n").split("\t")
            keys.append(f[0]); xs.append(float(f[1])); ys.append(float(f[2]))
            for p in f[5:]:
                a, b = p.split(" ")
                rows.append(r); cols.append(int(a)); vals.append(float(b))
    counts = sp.csr_matrix((vals, (rows, cols)), shape=(len(keys), len(genes)))
    return meta, genes, np.array(xs), np.array(ys), counts


def read_results(path):
    d = pd.read_csv(path, sep="\t")
    d.columns = [str(c).lstrip("#") for c in d.columns]
    return d


def read_model(path):
    d = pd.read_csv(path, sep="\t", index_col=0)
    return d


def write_run(sdata_path, run, hex_txt, hex_json, results, model, params,
              points_key="transcripts", coordinate_system=None,
              in_place_source=None, overwrite=False):
    import os
    import anndata as ad
    import spatialdata as sd
    from spatialdata.models import ShapesModel, TableModel
    from spatialdata.transformations import (Identity, get_transformation,
                                             set_transformation)

    meta, genes, hx, hy, counts = read_hex(hex_txt, hex_json)
    res = read_results(results)
    topic_cols = [c for c in res.columns if c not in ("random_key", "key", "x", "y")]
    idx = pd.Series(np.arange(len(hx)), index=_key(hx, hy))
    if idx.index.has_duplicates:
        raise ValueError("Hexagon centres in the count file are not unique.")
    pos = idx.reindex(_key(res["x"].to_numpy(), res["y"].to_numpy()))
    keep = pos.notna().to_numpy()
    if not keep.any():
        raise ValueError("No hexagon in the results file matches the count file.")
    if not keep.all():
        print(f"WARNING: {int((~keep).sum())} result rows have no matching hexagon; dropped.",
              file=sys.stderr)
    order = pos[keep].astype(int).to_numpy()
    res = res[keep].reset_index(drop=True)
    counts = counts[order]
    x = hx[order]; y = hy[order]
    topics = res[topic_cols].to_numpy(dtype=np.float32)

    mod = read_model(model)
    loadings = mod.reindex(genes)
    missing = loadings.isna().any(axis=1).to_numpy()
    load = loadings.fillna(0.0).to_numpy(dtype=np.float32)
    if missing.any():
        print(f"NOTE: {int(missing.sum())} of {len(genes)} genes are not in the model "
              "(filtered before training); their loadings are 0.", file=sys.stderr)

    shape_name = f"punkst_{run}_hexagons"
    table_name = f"punkst_{run}"

    if os.path.exists(sdata_path):
        target = sd.read_zarr(sdata_path)
    else:
        target = sd.SpatialData()
        target.write(sdata_path)
    exists = [n for n in (shape_name,) if n in target.shapes] + \
             [n for n in (table_name,) if n in target.tables]
    if exists and not overwrite:
        raise FileExistsError(
            f"Run '{run}' already exists in {sdata_path} ({exists}); "
            "use overwrite or choose another run name.")
    for n in exists:
        # remove from disk and memory before rewriting
        target.delete_element_from_disk(n)
        del target[n]

    # source transformations
    src_path = in_place_source or sdata_path
    if coordinate_system == "intrinsic":
        src = sd.read_zarr(src_path)
        if points_key not in src.points:
            raise KeyError(f"'{points_key}' not among Points elements: {list(src.points)}")
        transforms = get_transformation(src.points[points_key], get_all=True)
    elif coordinate_system is None:
        # exported in the element's only coordinate system, so the hexagons
        # are already expressed in it
        src = sd.read_zarr(src_path)
        only = list(get_transformation(src.points[points_key], get_all=True))
        if len(only) != 1:
            raise ValueError("Points element has several coordinate systems "
                             f"({only}); pass the one used for export.")
        transforms = {only[0]: Identity()}
    else:
        transforms = {coordinate_system: Identity()}

    radius = float(meta.get("hex_size", 1.0))
    coords = np.column_stack([x, y])
    shapes = ShapesModel.parse(coords, geometry=0, radius=np.full(len(x), radius),
                               index=np.arange(len(x)))
    for cs, t in transforms.items():
        set_transformation(shapes, t, cs)

    adata = ad.AnnData(X=counts.tocsr().astype(np.float32),
                       obs=pd.DataFrame({"instance_id": np.arange(len(x)),
                                         "region": pd.Categorical([shape_name] * len(x)),
                                         "x": x, "y": y,
                                         "total": np.asarray(counts.sum(axis=1)).ravel()},
                                        index=[f"hex{i}" for i in range(len(x))]),
                       var=pd.DataFrame(index=pd.Index(genes, name="gene")))
    adata.obsm["spatial"] = coords
    adata.obsm["topics"] = topics
    adata.varm["loadings"] = load
    adata.uns["topic_names"] = [str(c) for c in topic_cols]
    adata.uns["punkst"] = {"run": run, "hex_size": radius,
                           "n_topics": len(topic_cols), "params_json": json.dumps(params),
                           "coordinate_system": coordinate_system or "single"}
    adata.obs["top_topic"] = pd.Categorical(np.array(topic_cols)[topics.argmax(axis=1)])
    table = TableModel.parse(adata, region=shape_name, region_key="region",
                             instance_key="instance_id")

    target.shapes[shape_name] = shapes
    target.write_element(shape_name)
    target.tables[table_name] = table
    target.write_element(table_name)
    return {"shapes": shape_name, "table": table_name, "n_hexagons": int(len(x)),
            "n_topics": len(topic_cols), "n_genes": len(genes)}


def list_runs(sdata_path):
    import spatialdata as sd
    sdata = sd.read_zarr(sdata_path)
    out = []
    for name, t in sdata.tables.items():
        info = t.uns.get("punkst") if hasattr(t, "uns") else None
        if info is None:
            continue
        out.append({"run": str(info["run"]), "table": name,
                    "n_hexagons": int(t.n_obs), "n_genes": int(t.n_vars),
                    "n_topics": int(info["n_topics"]), "hex_size": float(info["hex_size"]),
                    "params": json.loads(str(info["params_json"]))})
    return out


if __name__ == "__main__":
    p = argparse.ArgumentParser(prog="punkst_to_sdata")
    sub = p.add_subparsers(dest="cmd", required=True)
    w = sub.add_parser("write")
    w.add_argument("--target", required=True, help="store to write into")
    w.add_argument("--source", default=None, help="store holding the Points element (if different)")
    w.add_argument("--run", required=True)
    w.add_argument("--hex", required=True)
    w.add_argument("--hex-json", required=True)
    w.add_argument("--results", required=True)
    w.add_argument("--model", required=True)
    w.add_argument("--params", required=True, help="JSON file of run parameters")
    w.add_argument("--points-key", default="transcripts")
    w.add_argument("--coordinate-system", default=None)
    w.add_argument("--overwrite", action="store_true")
    w.add_argument("--out", required=True, help="JSON summary")
    l = sub.add_parser("list")
    l.add_argument("--sdata", required=True)
    l.add_argument("--out", required=True)
    a = p.parse_args()
    if a.cmd == "write":
        with open(a.params) as fh:
            params = json.load(fh)
        r = write_run(a.target, a.run, a.hex, a.hex_json, a.results, a.model, params,
                      a.points_key, a.coordinate_system, a.source, a.overwrite)
    else:
        r = list_runs(a.sdata)
    with open(a.out, "w") as fh:
        json.dump(r, fh)
