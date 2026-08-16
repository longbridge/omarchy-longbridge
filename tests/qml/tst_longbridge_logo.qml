import QtQuick
import QtTest
import "../../components"

TestCase {
  name: "LongbridgeLogo"

  Component {
    id: logoComponent
    LongbridgeLogo { foregroundColor: "#abcdef" }
  }

  Component {
    id: brandLogoComponent
    LongbridgeLogo { foregroundColor: "#abcdef"; brandColors: true }
  }

  function test_officialGeometryAndThemeColor() {
    var logo = createTemporaryObject(logoComponent, this, { width: 69, height: 69 })
    verify(logo !== null)

    var foregroundTall = findChild(logo, "foregroundTall")
    var tealTall = findChild(logo, "tealTall")
    var yellowSquare = findChild(logo, "yellowSquare")
    var foregroundShort = findChild(logo, "foregroundShort")
    var orangeBlock = findChild(logo, "orangeBlock")
    var foregroundBlock = findChild(logo, "foregroundBlock")
    var orangeTall = findChild(logo, "orangeTall")

    compare([foregroundTall.x, foregroundTall.y, foregroundTall.width, foregroundTall.height], [0, 0, 3, 69])
    compare([tealTall.x, tealTall.y, tealTall.width, tealTall.height], [7, 0, 10, 69])
    compare([yellowSquare.x, yellowSquare.y, yellowSquare.width, yellowSquare.height], [21, 60, 9, 9])
    compare([foregroundShort.x, foregroundShort.y, foregroundShort.width, foregroundShort.height], [33, 60, 3, 9])
    compare([orangeBlock.x, orangeBlock.y, orangeBlock.width, orangeBlock.height], [40, 52, 10, 17])
    compare([foregroundBlock.x, foregroundBlock.y, foregroundBlock.width, foregroundBlock.height], [53, 43, 9, 26])
    compare([orangeTall.x, orangeTall.y, orangeTall.width, orangeTall.height], [66, 26, 3, 43])
    compare(foregroundTall.color.toString(), "#abcdef")
    compare(tealTall.color.toString(), "#abcdef")
    compare(yellowSquare.color.toString(), "#abcdef")
    compare(orangeBlock.color.toString(), "#abcdef")
    compare(orangeTall.color.toString(), "#abcdef")
  }

  function test_brandColorsAreOnlyEnabledExplicitly() {
    var logo = createTemporaryObject(brandLogoComponent, this, { width: 69, height: 69 })
    verify(logo !== null)
    compare(findChild(logo, "foregroundTall").color.toString(), "#abcdef")
    compare(findChild(logo, "tealTall").color.toString(), "#00dbb6")
    compare(findChild(logo, "yellowSquare").color.toString(), "#ffe000")
    compare(findChild(logo, "orangeBlock").color.toString(), "#fc5200")
    compare(findChild(logo, "orangeTall").color.toString(), "#fc5200")
  }
}
