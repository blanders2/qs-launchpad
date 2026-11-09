pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

// A small form that slides up over a module's list. Open it with
//   sheet.open({ title, submitLabel, fields: [...], submit: values => … })
// Field kinds: text (optional `secret`), choice (`options`; `submitOnPick` submits on click),
// multi (several options on at once; value is an array), toggle, host (text plus suggestion chips
// from `options`) and note (plain text). A field with `when: values => bool` only shows when it's true. Each field has key, label, value, placeholder, hint.
// `submit` runs the action; it sets sheet.error / sheet.busy, calls sheet.ask(question) to confirm
// first (submit runs again with values.confirmed = true), or sheet.close() when done.
Rectangle {
    id: sheet

    property bool shown: false
    property string title
    property string submitLabel: "Save"
    property var fields: []
    property var values: ({})
    property string error: ""
    property bool busy: false
    property string question: ""
    property var submitFn: null
    property double lastSubmit: 0
    signal closed()

    function open(spec) {
        title = spec.title || "";
        submitLabel = spec.submitLabel || "Save";
        fields = spec.fields || [];
        const v = {};
        fields.forEach(f => { if (f.key) v[f.key] = f.value !== undefined ? f.value : f.kind === "toggle" ? false : ""; });
        values = v;
        submitFn = spec.submit;
        error = "";
        busy = false;
        question = "";
        shown = true;
        Qt.callLater(() => { const first = form.firstInput(); first ? first.forceActiveFocus() : sheet.forceActiveFocus(); });
    }
    function close() {
        if (!shown) return;
        shown = false;
        closed();
    }
    function set(key, value) {
        const v = Object.assign({}, values);
        v[key] = value;
        values = v;
        error = "";
        question = "";
    }
    function ask(text) { question = text; busy = false; }
    function submit() {
        // Enter can reach us both from a field's accepted() and the sheet's own key handler.
        if (busy || !submitFn || Date.now() - lastSubmit < 250) return;
        lastSubmit = Date.now();
        error = "";
        const confirmed = question !== "";
        submitFn(Object.assign({}, values, { confirmed: confirmed }));
    }

    visible: shown || slide.running
    y: shown ? 0 : height + 20
    Behavior on y { NumberAnimation { id: slide; duration: 240; easing.type: Easing.OutCubic } }
    radius: 12
    color: "#f6201f1d"
    border.width: 1
    border.color: Theme.line
    focus: shown

    Keys.onEscapePressed: question ? question = "" : sheet.close()
    Keys.onReturnPressed: sheet.submit()
    Keys.onEnterPressed: sheet.submit()

    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

    ColumnLayout {
        anchors { fill: parent; margins: 16 }
        spacing: 12

        Text {
            text: sheet.title
            color: Theme.text
            font { family: Theme.font; pixelSize: 15; weight: Font.DemiBold }
        }

        Flickable {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentHeight: form.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: form
                width: parent.width
                spacing: 12

                function firstInput() {
                    for (let i = 0; i < repeater.count; i++) {
                        const it = repeater.itemAt(i);
                        if (it && it.visible && it.input) return it.input;
                    }
                    return null;
                }

                Repeater {
                    id: repeater
                    model: sheet.fields
                    delegate: ColumnLayout {
                        id: field
                        required property var modelData
                        readonly property var f: modelData
                        readonly property var value: sheet.values[f.key]
                        property Item input: textField.visible ? textInput : null
                        visible: !f.when || f.when(sheet.values)
                        Layout.fillWidth: true
                        spacing: 5

                        Text {
                            visible: !!field.f.label
                            text: field.f.label || ""
                            color: Theme.dim
                            font { family: Theme.font; pixelSize: 12 }
                        }

                        // text / host
                        Rectangle {
                            id: textField
                            visible: field.f.kind === "text" || field.f.kind === "host"
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: 8
                            color: Theme.raised
                            border.width: 1
                            border.color: textInput.activeFocus ? Theme.accentSoft : Theme.line
                            TextInput {
                                id: textInput
                                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                                verticalAlignment: TextInput.AlignVCenter
                                text: field.visible && typeof field.value === "string" ? field.value : String(field.value ?? "")
                                echoMode: field.f.secret ? TextInput.Password : TextInput.Normal
                                color: Theme.text
                                selectionColor: Theme.accent
                                font { family: field.f.mono ? Theme.mono : Theme.font; pixelSize: 13 }
                                clip: true
                                activeFocusOnTab: true
                                onTextEdited: sheet.set(field.f.key, text)
                                onAccepted: sheet.submit()
                                Text {
                                    visible: !textInput.text
                                    text: field.f.placeholder || ""
                                    color: Theme.faint
                                    font: textInput.font
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                        }

                        // choice / multi / host suggestions
                        Flow {
                            visible: ["choice", "multi", "host"].indexOf(field.f.kind) >= 0 && (field.f.options || []).length > 0
                            Layout.fillWidth: true
                            spacing: 5
                            Repeater {
                                model: field.f.options || []
                                delegate: Chip {
                                    required property var modelData
                                    readonly property var opt: typeof modelData === "object" ? modelData : { value: modelData, label: modelData }
                                    label: opt.label
                                    readonly property bool multi: field.f.kind === "multi"
                                    lit: multi ? (field.value || []).indexOf(opt.value) >= 0 : field.value === opt.value
                                    onClicked: {
                                        if (multi) {
                                            const on = (field.value || []).filter(x => x !== opt.value);
                                            sheet.set(field.f.key, lit ? on : on.concat([opt.value]));
                                            return;
                                        }
                                        sheet.set(field.f.key, opt.value);
                                        if (field.f.submitOnPick) sheet.submit();
                                    }
                                }
                            }
                        }

                        // toggle
                        Row {
                            visible: field.f.kind === "toggle"
                            spacing: 8
                            Rectangle {
                                width: 34
                                height: 18
                                radius: 9
                                color: field.value === true ? Theme.accent : Theme.hover
                                Rectangle {
                                    x: field.value === true ? parent.width - width - 2 : 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: 7
                                    color: Theme.text
                                    Behavior on x { NumberAnimation { duration: 120 } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: sheet.set(field.f.key, field.value !== true)
                                }
                            }
                            Text {
                                text: field.f.text || ""
                                color: Theme.dim
                                font { family: Theme.font; pixelSize: 12 }
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        Text {
                            visible: !!field.f.hint || field.f.kind === "note"
                            Layout.fillWidth: true
                            text: field.f.kind === "note" ? field.f.text || "" : field.f.hint || ""
                            color: field.f.warn ? Theme.warn : Theme.faint
                            wrapMode: Text.Wrap
                            font { family: Theme.font; pixelSize: 11 }
                        }
                    }
                }
            }
        }

        Text {
            visible: !!sheet.error || !!sheet.question
            Layout.fillWidth: true
            text: sheet.question || sheet.error
            color: sheet.question ? Theme.warn : Theme.bad
            wrapMode: Text.Wrap
            font { family: Theme.font; pixelSize: 12 }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text {
                visible: sheet.busy
                text: "Working…"
                color: Theme.faint
                font { family: Theme.font; pixelSize: 12 }
            }
            Item { Layout.fillWidth: true }
            Button {
                label: sheet.question ? "Back" : "Cancel"
                onClicked: sheet.question ? sheet.question = "" : sheet.close()
            }
            Button {
                label: sheet.question ? "Yes, go ahead" : sheet.submitLabel
                primary: true
                enabled: !sheet.busy
                onClicked: sheet.submit()
            }
        }
    }

    component Button: Rectangle {
        id: btn
        property string label
        property bool primary: false
        property bool enabled: true
        signal clicked()
        implicitWidth: btnText.implicitWidth + 24
        implicitHeight: 30
        radius: 8
        opacity: enabled ? 1 : 0.5
        color: primary ? (btnArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent) : btnArea.containsMouse ? Theme.hover : Theme.raised
        Text {
            id: btnText
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? "#1d1c1a" : Theme.text
            font { family: Theme.font; pixelSize: 12; weight: btn.primary ? Font.DemiBold : Font.Normal }
        }
        MouseArea {
            id: btnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (btn.enabled) btn.clicked()
        }
    }
}
