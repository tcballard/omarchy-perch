pragma Singleton
import QtQuick
import "LanguagePolicy.js" as Language

QtObject {
    property string language: "en"
    function t(text) {
        return Language.translate(text, language);
    }
}
