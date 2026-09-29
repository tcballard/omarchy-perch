#!/usr/bin/env python3
"""Render production NotchView with explicit theme stubs, never a live-shell claim."""
import os
os.environ.setdefault('QT_QPA_PLATFORM','offscreen')
os.environ.setdefault('QT_QUICK_BACKEND','software')
os.environ.setdefault('QT_QUICK_CONTROLS_STYLE','Basic')
import sys
from pathlib import Path
from PySide6.QtCore import QUrl, QTimer, QObject, qInstallMessageHandler
from PySide6.QtGui import QGuiApplication
from PySide6.QtQuick import QQuickView
root=Path(__file__).resolve().parent
warnings=[]
def handler(kind, context, message):
    warnings.append(message)
    print(message, file=sys.stderr)
qInstallMessageHandler(handler)
app=QGuiApplication(sys.argv)
view=QQuickView()
view.engine().addImportPath(str(root/'stubs'))
view.setSource(QUrl.fromLocalFile(str(root/'Preview.qml')))
if view.status()==QQuickView.Error: raise SystemExit(1)
view.show()
def save():
    output=Path(sys.argv[1]) if len(sys.argv)>1 else root.parent/'preview.png'
    output.parent.mkdir(parents=True,exist_ok=True)
    assert view.grabWindow().save(str(output))
    print('Rendered production NotchView with fictional media and theme stubs:',output)
    app.exit(1 if warnings else 0)
QTimer.singleShot(500,save)
sys.exit(app.exec())
