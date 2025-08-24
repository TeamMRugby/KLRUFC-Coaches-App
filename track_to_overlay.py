
# Minimal YOLOv8 -> overlay JSON exporter for person tracking
# Usage: python track_to_overlay.py input.mp4 output.json
# Requires: pip install ultralytics supervision opencv-python
import sys, json, cv2
from ultralytics import YOLO
import supervision as sv

def main(src, out_json):
    model = YOLO('yolov8n.pt')
    tracker = sv.ByteTrack()
    cap = cv2.VideoCapture(src)
    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0

    tracks = {}  # id -> list of points
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        t = i / fps
        results = model(frame, verbose=False)[0]
        detections = sv.Detections.from_ultralytics(results)
        # class filter: person == 0 for COCO
        mask = detections.class_id == 0
        detections = detections[mask]
        tracked = tracker.update_with_detections(detections)

        for xyxy, tid in zip(tracked.xyxy, tracked.tracker_id):
            x1,y1,x2,y2 = xyxy
            cx = float((x1 + x2)/2) / frame.shape[1]
            cy = float((y1 + y2)/2) / frame.shape[0]
            tracks.setdefault(int(tid), []).append({"t": round(t,3), "x": round(cx,4), "y": round(cy,4)})
        i += 1

    players = [{"id": pid, "color": None, "label": str(pid)} for pid in tracks.keys()]
    out = {"fps": fps, "players": players, "tracks": [{"id": pid, "points": pts} for pid, pts in tracks.items()], "events": []}
    with open(out_json, "w") as f:
        json.dump(out, f)
    print(f"Wrote {out_json}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: python track_to_overlay.py input.mp4 output.json")
        sys.exit(1)
    main(sys.argv[1], sys.argv[2])
