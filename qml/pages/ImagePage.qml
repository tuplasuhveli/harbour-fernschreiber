/*
    Copyright (C) 2020 Sebastian J. Wolf

    This file is part of Fernschreiber.

    Fernschreiber is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    Fernschreiber is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Fernschreiber. If not, see <http://www.gnu.org/licenses/>.
*/
import QtQuick 2.0
import Sailfish.Silica 1.0
import QtMultimedia 5.0
import "../components"
import "../js/functions.js" as Functions

Page {
    id: imagePage
    allowedOrientations: Orientation.All

    property variant photoData;
    property variant pictureFileInformation;

    property string imageUrl;
    property int imageWidth;
    property int imageHeight;

    property real imageSizeFactor : imageWidth / imageHeight;
    property real screenSizeFactor: imagePage.width / imagePage.height;
    property real sizingFactor    : imageSizeFactor >= screenSizeFactor ? imagePage.width / imageWidth : imagePage.height / imageHeight;

    property real previousScale : 1;
    property real centerX;
    property real centerY;
    property real oldCenterX;
    property real oldCenterY;

    Component.onCompleted: {
        updatePicture();
    }

    function updatePicture() {
        if (typeof photoData === "object") {
            // Check first which size fits best...
            for (var i = 0; i < photoData.sizes.length; i++) {
                imagePage.imageWidth = photoData.sizes[i].width;
                imagePage.imageHeight = photoData.sizes[i].height;
                imagePage.pictureFileInformation = photoData.sizes[i].photo;
                if (photoData.sizes[i].width >= imagePage.width) {
                    break;
                }
            }

            if (imagePage.pictureFileInformation.local.is_downloading_completed) {
                imagePage.imageUrl = imagePage.pictureFileInformation.local.path;
            } else {
                tdLibWrapper.downloadFile(imagePage.pictureFileInformation.id);
            }
        }
    }

    Connections {
        target: tdLibWrapper
        onFileUpdated: {
            if (fileId === imagePage.pictureFileInformation.id) {
                console.log("File updated, completed? " + fileInformation.local.is_downloading_completed);
                if (fileInformation.local.is_downloading_completed) {
                    imagePage.pictureFileInformation = fileInformation;
                    imagePage.imageUrl = fileInformation.local.path;
                }
            }
        }
        onCopyToDownloadsSuccessful: {
            imageNotification.show(qsTr("Download of %1 successful.").arg(fileName), filePath);
        }

        onCopyToDownloadsError: {
            imageNotification.show(qsTr("Download failed."));
        }
    }

    SilicaFlickable {
        id: imageFlickable
        anchors.fill: parent
        clip: true
        contentWidth: imagePinchArea.width;
        contentHeight: imagePinchArea.height;

        PullDownMenu {
            visible: (typeof imagePage.imageUrl !== "undefined")
            MenuItem {
                text: qsTr("Download Picture")
                onClicked: {
                    tdLibWrapper.copyFileToDownloads(imagePage.imageUrl);
                }
            }
        }

        transitions: Transition {
            NumberAnimation { properties: "contentX, contentY"; easing.type: Easing.Linear }
        }

        AppNotification {
            id: imageNotification
        }

        PinchArea {
            id: imagePinchArea
            width:  Math.max( singleImage.width * singleImage.scale, imageFlickable.width )
            height: Math.max( singleImage.height * singleImage.scale, imageFlickable.height )

            enabled: singleImage.visible
            pinch {
                target: singleImage
                minimumScale: 1
                maximumScale: 4
            }

            onPinchUpdated: {
                imagePage.centerX = pinch.center.x;
                imagePage.centerY = pinch.center.y;
            }

            Image {
                id: singleImage
                source: imageUrl
                width: imagePage.imageWidth * imagePage.sizingFactor
                height: imagePage.imageHeight * imagePage.sizingFactor
                anchors.centerIn: parent

                fillMode: Image.PreserveAspectFit

                visible: status === Image.Ready ? true : false
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity { NumberAnimation {} }
                onScaleChanged: {
                    var newWidth = singleImage.width * singleImage.scale;
                    var newHeight = singleImage.height * singleImage.scale;
                    var oldWidth = singleImage.width * imagePage.previousScale;
                    var oldHeight = singleImage.height * imagePage.previousScale;
                    var widthDifference = newWidth - oldWidth;
                    var heightDifference = newHeight - oldHeight;

                    if (oldWidth > imageFlickable.width || newWidth > imageFlickable.width) {
                        var xRatioNew = imagePage.centerX / newWidth;
                        var xRatioOld = imagePage.centerX / oldHeight;
                        imageFlickable.contentX = imageFlickable.contentX + ( xRatioNew * widthDifference );
                    }
                    if (oldHeight > imageFlickable.height || newHeight > imageFlickable.height) {
                        var yRatioNew = imagePage.centerY / newHeight;
                        var yRatioOld = imagePage.centerY / oldHeight;
                        imageFlickable.contentY = imageFlickable.contentY + ( yRatioNew * heightDifference );
                    }

                    imagePage.previousScale = singleImage.scale;
                    imagePage.oldCenterX = imagePage.centerX;
                    imagePage.oldCenterY = imagePage.centerY;
                }
            }
        }

    }

    Image {
        id: imageLoadingBackgroundImage
        source: "../../images/background" + ( Theme.colorScheme ? "-black" : "-white" ) + ".png"
        anchors {
            centerIn: parent
        }
        width: parent.width - Theme.paddingMedium
        height: parent.height - Theme.paddingMedium
        visible: singleImage.status !== Image.Ready

        fillMode: Image.PreserveAspectFit
        opacity: 0.15
    }

}
