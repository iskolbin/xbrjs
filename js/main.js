"use strict";

function onImageLoaded( inputCanvas ) {
	var list = document.getElementById( "input-image" );
	list.removeChild( list.childNodes[0] );
	list.appendChild( inputCanvas );
	var ctx = inputCanvas.getContext('2d');
	var count = inputCanvas.width * inputCanvas.height;
	var data = ctx.getImageData(0, 0, inputCanvas.width, inputCanvas.height).data;
	var original = new Array(count);
	for (var i = 0; i < count; i++) {
		var index = i << 2;
		original[i] = (data[index + 3] << 24) + (data[index + 2] << 16) + (data[index + 1] << 8) + data[index];
	}

	var result = document.superxbr(original, inputCanvas.width, inputCanvas.height);
	var outputCanvas = document.getElementById( "output-canvas" );
	var octx = outputCanvas.getContext('2d');
	outputCanvas.width = inputCanvas.width * 2;
	outputCanvas.height = inputCanvas.height * 2;

	var newImageData = octx.getImageData(0, 0, outputCanvas.width, outputCanvas.height);
	var dest = newImageData.data;
	for (var i = 0; i < count * 4; i++) {
		var index = i << 2;
		dest[index] = result[i] & 255;
		dest[index + 1] = (result[i] >> 8) & 255;
		dest[index + 2] = (result[i] >> 16) & 255;
		dest[index + 3] = (result[i] >> 24) & 255;
	}
	octx.putImageData(newImageData, 0, 0);
}

document.getElementById("file-input").onchange = function(e) {
	var loadingImage = loadImage( e.target.files[0], onImageLoaded, {"canvas": true} );
}

document.getElementById("btn-download").onclick = function(e) {
	var canvas = document.getElementById("output-canvas");
	var button = document.getElementById("btn-download");
	var dataURL = canvas.toDataURL('image/png');
	button.href = dataURL;
}
