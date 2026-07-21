import os
import sys

def check_months():
    base_dir = "expedientes"
    if not os.path.isdir(base_dir):
        print("No expedientes folder")
        return
    
    for period in sorted(os.listdir(base_dir)):
        if not period.startswith("2025-"):
            continue
        
        tramas_dir = os.path.join(base_dir, period, "01_TRAMAS")
        if not os.path.isdir(tramas_dir):
            continue
            
        print(f"--- Periodo: {period} ---")
        
        # Load .trama_columns.json
        import json
        cols_path = os.path.join(base_dir, period, "03_INFORMATIVOS", ".trama_columns.json")
        try:
            with open(cols_path, 'r') as f:
                cols = json.load(f)
        except:
            print("No .trama_columns.json")
            continue
            
        # Check files
        for fname in ["trama_consulta_externa.txt", "trama_emergencia.txt", "trama_hospitalizacion.txt", "trama_farmacia.txt"]:
            fpath = os.path.join(tramas_dir, fname)
            if not os.path.exists(fpath):
                print(f"{fname}: Missing")
                continue
                
            with open(fpath, "r", encoding="utf-8") as f:
                lines = [l.strip() for l in f.readlines() if l.strip()]
            
            # Find date columns
            date_cols = []
            if "consulta" in fname:
                cname = "consulta"
                date_cols = ["sp_fecha_atencion"]
            elif "emergencia" in fname:
                cname = "emergencia"
                date_cols = ["sp_fecha_atencion"] # or sp_fecha_alta
            elif "hospitalizacion" in fname:
                cname = "hospitalizacion"
                date_cols = ["sp_fecha_atencion"]
            elif "farmacia" in fname:
                cname = "farmacia"
                date_cols = ["fecha_dispensacion", "fecha_atencion_medica"]
                
            c_list = cols.get(cname, [])
            if not c_list:
                print(f"{fname}: 0 rows (columns empty)")
                continue
                
            date_indices = []
            for dc in date_cols:
                if dc in c_list:
                    date_indices.append(c_list.index(dc))
            
            dates = set()
            for line in lines:
                parts = line.split("|")
                for idx in date_indices:
                    if idx < len(parts):
                        val = parts[idx].strip()
                        if val:
                            if " " in val:
                                val = val.split(" ")[0]
                            dates.add(val)
                            
            # Check if all dates match period
            bad_dates = set()
            for d in dates:
                if d and not d.startswith(period):
                    bad_dates.add(d)
                    
            print(f"{fname}: {len(lines)} rows. Bad dates: {list(bad_dates)[:5]}{'...' if len(bad_dates)>5 else ''} (Total bad: {len(bad_dates)})")

if __name__ == "__main__":
    check_months()
