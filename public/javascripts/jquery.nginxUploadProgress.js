jQuery.nginxUploadProgress = function(settings) {
	settings = jQuery.extend({
		interval: 2000,
		progress_bar_id: "progressbar",
		nginx_progress_url: "/progress"
	}, settings);

	this.timer = setInterval(function() { jQuery.nginxUploadProgressFetch(this, settings['nginx_progress_url'], settings['progress_bar_id'], settings['uuid']) }, settings['interval']);
};

jQuery.nginxUploadProgress.inum = 0;

jQuery.nginxUploadProgressFetch = function(e, nginx_progress_url, progress_bar_id, uuid) {
	// window.console.log("fetcing progress for "+uuid)
	jQuery.nginxUploadProgress.inum++;
	
	$.ajax({
		type: "GET",
		url: nginx_progress_url,
		dataType: "json",
		beforeSend: function(xhr) {
			xhr.setRequestHeader("X-Progress-ID", uuid);
			// window.console.log("setting headers: "+uuid)
		},
		complete: function(xhr, statusText) {
			// window.console.log("complete!: "+statusText);
		},
		success: function(upload) {
			/* change the width if the inner progress-bar */
			// window.console.log("got ajax response")
			// window.console.log(objToString(upload));
			if (upload.state == 'uploading') {
				bar = $('#'+progress_bar_id);
				w = Math.floor((upload.received / upload.size)*100);
				bar.width(w + '%');
				
				// Panda specific
				bar.show();
				
				// Update ETA
				eta_seconds = ((upload.size / upload.received) * jQuery.nginxUploadProgress.inum) - jQuery.nginxUploadProgress.inum;
				
				if (eta_seconds < 60) {
					eta_str = "under a minute"
				} else if (eta_seconds < (60*5)) {
					eta_str = "a few minutes"
				} else if (eta_seconds < (60*15)) {
					eta_str = "fifteen minutes"
				} else if (eta_seconds < (60*30)) {
					eta_str = "about half an hour"
				} else if (eta_seconds < (60*45)) {
					eta_str = "around 45 minutes"
				} else if (eta_seconds < (60*60)) {
					eta_str = "less than an hour"
				} else if (eta_seconds > (60*60)) {
					eta_str = "over an hour";
				} else if (eta_seconds > (60*60*2)) {
					eta_str = "a few hours";
				} else if (eta_seconds > (60*60*3)) {
					eta_str = "several hours";
				} else if (eta_seconds > (60*60*6)) {
					eta_str = "quite a long time... at least 6 hours";
				}
				
				$("#eta").html(eta_str);
			} else if (upload.state == 'error') {	
	      $('#uploading').hide();
				if (upload.status == 413) {
					$('#error').html("Sorry, that video file is too large. Could you resave it as a smaller one (under 60MB) please?");
				} else {
					$('#error').html('Unfortunately there was an error uploading your video. We have been notified of this issue. Please try uploading your video again shortly.');
				}
			}
			/* we are done, stop the interval */
			// if (upload.state == 'done') {
			// 	window.clearTimeout(e.timer);
			// }
		}
	});
};