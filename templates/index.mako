<%inherit file="/base_panels.mako"/>
<%def name="main_body()">
<style type="text/css">
td, th {
vertical-align: top;
}
</style>
<div class="body" style="max-width: 720px; margin: 0 auto;">
    <h2>Galaxy Cloudman Console</h2>
	<div id="main_text">
		%if initial_cluster_type is None:
			Welcome to Galaxy Cloudman.  This application will allow you to manage this cloud and the services provided within. If this is your first time running this cluster, you will need to select an initial data volume size.  Once the data store is configured, default services will start and you will be add and remove additional services as well as 'worker' nodes on which jobs are run.
		%else:
			Welcome to Galaxy Cloudman.  This application allows you to manage this instance of Galaxy.  Your previous data store has been reconnected.  Once Galaxy has initialized, use the controls below to add and remove 'worker' nodes for running jobs.
		%endif
	</div>
	<div style="clear: both;"></div><br/>
	<div style='position:relative;text-align:center;'>
		<ul style='display:inline;padding:0;'>
			<li style='display:inline;width:150px;'>
				<a id="stop-button" original-title="Terminate Cluster" class="action-button left-button">Terminate cluster</a>
			</li>
			<li style='display:inline;width:150px;'>
	        	<a class="action-button" original-title="Add Nodes..." id="scale_up_button">Add nodes <img src="/cloud/static/images/downarrow.png"></a>
			</li>
			<li style='display:inline;width:150px;'>
	        	<a class="action-button" original-title="Remove Nodes..." id="scale_down_button">Remove nodes <img src="/cloud/static/images/downarrow.png"></a>
			</li>
			<li style='display:inline;width:150px;'>
				<a id='dns' href='' original-title="Access Galaxy" class="action-button right-button">Access Galaxy</a>
			</li>
		</ul>

	<div id='cluster_scale_up_popup' class='cluster_scale_popup'>
		<h4>Add nodes</h4>
		<form id="add_instances_form" name="node_management_form" action="${h.url_for(controller='root',action='add_instances')}" method="post">
        <div class="form-row">
	        <label>Number of nodes to start:</label>
	        <div id="num_nodes" class="form-row-input">
	            <input type="text" name="number_nodes" class="LV_field" id="number_nodes" value="0" size="10">
				<div class="LV_msgbox"><span id="number_nodes_vtag"></span></div>
	        </div>
			<br/>
	        <label>Type of Nodes(s):</label>
			<div id="instance_type" class="form-row-input">
		    	<select name="instance_type" id="instance_type">
					<option value=''>Same as Master</option>
					<option value='t1.micro'>Micro</option>
					<option value='m1.large'>Large</option>
					<option value='m1.xlarge'>Extra Large</option>
					<option value='m2.xlarge'>High-Memory Extra Large</option>
					<option value='m2.2xlarge'>High-Memory Double Extra Large</option>
					<option value='m2.4xlarge'>High-Memory Quadruple Extra Large</option>
					## <option value='c1.medium'>High-CPU Medium</option>
					<option value='c1.xlarge'>High-CPU Extra Large</option>
				</select>
			</div>
	        <div class="form-row"><input type="submit" value="Start Additional Nodes"></div>
        </div>
	    </form>
	</div>
	<div id='cluster_scale_down_popup' class='cluster_scale_popup'>
	    <h4>Remove nodes</h4>
	    <form id="remove_instances_form" name="node_management_form" action="${h.url_for(controller='root',action='remove_instances')}" method="post">
	        <div class="form-row">
		        <div id="num_nodes" class="form-row-input">
		            <label>Number of nodes to remove:</label><input type="text" name="number_nodes" id="number_nodes" value="0" size="10">
		        </div>
		        <div id="num_nodes" class="form-row-input">
					&nbsp;
		        </div>
		        <div id="force_termination" class="form-row-input">
		            <label>Force Termination of non-idle nodes?</label>
					Yes<input type="radio" name="force_termination" id="force_termination" value="True">
					No<input type="radio" name="force_termination" id="force_termination" value="False"  checked="True">
		        </div>
		        <div id="num_nodes" class="form-row-input">
					&nbsp;
		        </div>
		        <div class="form-row"><input type="submit" value="Remove Existing Nodes"></div>
	        </div>
	    </form>
	</div>
</div>
<h2>Status</h2>
<div id="status_container">
    <div id="cluster_view">
	    <div id="cluster_view_tooltip" style="text-align: center;"></div>
	    <canvas id="cluster_canvas" width="150" height="120"></canvas>
    </div>
    <table cellpadding="0" cellspacing="10">
			%if cluster_name:
			    <tr><td><h4>Cluster name: </h4></td><td><span id="cluster_name">${cluster_name}</span></td></tr>
			%endif
	    <tr><td><h4>Disk status: </h4></td><td>
	        <span id="du-used">0</span> / <span id="du-total">0</span> (<span id="du-pct">0</span>) <span id='expand_vol' style='cursor: pointer;background-image:url(/cloud/static/images/disc_plus.png); background-repeat:no-repeat; display:inline-block; width:20px;'>&nbsp;</span>
	    	##<span id="snap-status"></span><span id="snap-progress"></span>
		</td></tr>
	    <tr><td><h4>Worker status: </h4></td><td>
	        <b>Idle</b>: <span id="status-idle">0</span>
	        <b>Available</b>: <span id="status-available">0</span>
	        <b>Requested</b>: <span id="status-total">0</span>
	    </td></tr>
	    <tr><td><h4>Service status: </h4></td><td>
			Applications <div id="app-status" style="width:16px;display:inline-block" class="status_green">&nbsp;</div>
			Data <div id="data-status" style="width:16px;display:inline-block" class="status_green">&nbsp;</div>
	    </td></tr>

	    <tr><td colspan=2></td></tr>
    </table>
</div>

## ****************************************************************************
## ***************************** Overlays and such ****************************
## ****************************************************************************

<div class="box" id="volume_expand_popup">
   <a class="boxclose"></a>
	<h2>Expand Disk Space</h2>
	<form id="expand_user_data_volume" name="expand_user_data_volume" action="${h.url_for(controller='root',action='expand_user_data_volume')}" method="post">
		<div class="form-row">
		Through this form you may increase the disk space available to Galaxy. All of the cluster services (but not the cluster)
		<b>WILL BE SHUT DOWN</b> until the new disk is ready, at which point they will all be restarted. This may result in Galaxy 
		jobs that are currently running to fail. Note that the new disk size <b>must be larger</b> than the current disk size.
		<p>During this process, a snapshot of your data volume will be created, which can optionally be left in you account. 
		If you decide to leave the snapshot, for reference, you may also provide a brief note that will later be visible in
		the snapshot description.</p>
		</div>
		<div class="form-row">
			<label>New Disk Size (max 1000GB):</label>
			<div id="permanent_storage_size" class="form-row-input">
				<input type="text" name="new_vol_size" id="new_vol_size" value="0" size="10">
			</div>
			<label>Note (optional):</label>
			<div id="permanent_storage_size" class="form-row-input">
				<input type="text" name="vol_expand_desc" id="vol_expand_desc" value="" size="40"><br/>
			</div>
			<label>or delete created snapshot after filesystem resizing?</label>
			<input type="checkbox" name="delete_snap" id="delete_snap"> If checked, the created snapshot will be deleted
			<div class="form-row">
				<input type="submit" value="Create Data Volume"/>
			</div>
		</div>
	</form>
</div>

<div style="clear: both;"></div>
<div class="overlay" id="overlay" style="display:none"></div>
<div class="box" id="power_off">
    <a class="boxclose"></a>
    <h1>EC2 Cluster Configuration</h1>
    <form id="power_cluster_off_form" name="power_cluster_form" action="${h.url_for(controller='root',action='kill_all')}" method="post">
        <div class="form-row">
            <label>Are you sure you want to power the cluster off?</label>
            <div class="form-row"><input type="submit" value="Yes, power off"></div>
        </div>
    </form>
</div>

<div style="clear: both;"></div>
## Autoscaling link
##Autoscaling is <span id='autoscaling_status'>N/A</span>. Turn <a id="toggle_autoscaling_link" style="text-decoration: underline; cursor: pointer;">N/A</a>?
## Autoscaling configuration popup
<div class="box" id="turn_autoscaling_off">
    <a class="boxclose"></a>
    <h2>Autoscaling Configuration</h2>
	<form id="turn_autoscaling_off_form" name="turn_autoscaling_off_form" action="${h.url_for(controller='root', action='toggle_autoscaling')}" method="post">
        <div class="form-row">
            If autoscaling is turned off, the cluster will remain in it's current state and you will
			be able to manually add or remove nodes.
			<div class="form-row"><input type="submit" value="Turn autoscaling off"/></div>
        </div>
    </form>
</div>
<div class="box" id="turn_autoscaling_on">
	<a class="boxclose"></a>
	<h2>Autoscaling Configuration</h2>
	<form id="turn_autoscaling_on_form" name="turn_autoscaling_on_form" action="${h.url_for(controller='root', action='toggle_autoscaling')}" method="post">
        <div class="form-row">
            Autoscaling attempts to automate the elasticity offered by cloud computing for this 
			particular cluster. <b>Once turned on, autoscaling takes over the control over the size 
			of your cluster.</b> Before turning autoscaling on, specify the cluster size limits you 
			want to ensure are respected by autoscaling and use your cluster as you normally do.
			The cluster will never be smaller than the minimum number of worker nodes you specify 
			and it will never grow larger than the maximum number of worker nodes you specify.
			Within those limits, if there are more jobs than the cluster can comfortably process at
			a given time, autoscaling will automatically add compute nodes; if there are cluster nodes
			sitting idle at the end of an hour, autoscaling will terminate those nodes, thus reducing
			the size of the cluster and	your cost. 
			<p>Once turned on, the cluster size limits respected by autoscaling can be adjusted or 
			autoscaling can be turned off.</p>
			<div class="form-row">
				<label>Min number of nodes to maintain:</label>
				<div class="form-row-input">
					<input type="text" name="as_min" id="as_min" value="" size="10">
				</div>
				<label>Max number of nodes to maintain</label>
				<div class="form-row-input">
					<input type="text" name="as_max" id="as_max" value="" size="10">
				</div>
				<div class="form-row"><input type="submit" value="Turn autoscaling on"/></div>
			</div>
        </div>
    </form>
</div>
<div class="box" id="adjust_autoscaling">
	<a class="boxclose"></a>
	<h2>Adjust Autoscaling Configuration</h2>
	<form id="adjust_autoscaling_form" name="adjust_autoscaling_form" action="${h.url_for(controller='root', action='adjust_autoscaling')}" method="post">
        <div class="form-row">
            Adjust the number of instances autoscaling should maintain for this cluster. 
			<p>NOTE that <b>if there are no idle nodes to remove</b>, although the maximum 
			limit may be higher than the number of available nodes, autoscaling will wait 
			until the nodes become idle to terminate them.
			<div class="form-row">
				<label>Min number of nodes to maintain:</label>
				<div class="form-row-input">
					<input type="text" name="as_min_adj" id="as_min_adj" value="" size="10">
				</div>
				<label>Max number of nodes to maintain</label>
				<div class="form-row-input">
					<input type="text" name="as_max_adj" id="as_max_adj" value="" size="10">
				</div>
				<div class="form-row"><input type="submit" value="Adjust autoscaling"/></div>
			</div>
        </div>
    </form>
</div>

<div id="voloverlay" class="overlay" style="display:none"></div>
<div id="popupoverlay" class="overlay" style="display:none"></div>
<div class="box" id="volume_config">
	<h2>Initial Cluster Configuration</h2>
	<div class="form-row">
		<p>Welcome to Galaxy Cloudman.  This application will allow you to manage this cluster and the services provided within. To get started, choose the type of cluster you'd like to work with and specify the size of your persistent data storage, if any.</p>
	</div>
	<form id="initial_volume_config_form" name="power_cluster_form" action="${h.url_for(controller='root',action='initialize_cluster')}" method="post">
		<div class="form-row">
			<p><input type="radio" name="startup_opt" value="Galaxy" checked='true'>Start a full Galaxy Cluster. Specify initial storage size (in Gigabytes)</p>
			<input style="margin-left:20px" type="text" name="g_pss" class="LV_field" id="g_pss" value="" size="3">GB<span id="g_pss_vtag"></span>
		</div>
		<div id='extra_startup_options'>
			<div class="form-row">
				<p><input type="radio" name="startup_opt" value="Data">Data volume and SGE only. Specify initial storage size (in Gigabytes)</p>
				<input style="margin-left:20px"  type="text" name="d_pss" class="LV_field" id="d_pss" value="" size="3">GB<span id="d_pss_vtag"></span>
			</div>
			
			<div class="form-row">
				<p><input type="radio" name="startup_opt" value="SGE">SGE Only. No persistent storage created.</p>
			</div>
		</div>
		<div id="toggle_extra_startup_options_cont" class="form-row"><a id='toggle_extra_startup_options' href="#">Show more startup options</a></div>
		<br/>
		<div class="form-row" style="text-align:center;">
			<input type="submit" value="Start Cluster" id="start_cluster_submit_btn"/>
		</div>
		</form>
	</div>
</div>

<div id="log_container">
    <div id="status_svcs" style="display:none;">
        <ul><li class='fs_det_clicker'><div class='status_nodata'>&nbsp;</div>Filesystems</li>
        <li><div class='status_nodata'>&nbsp;</div>Scheduler</li>
        <li><div class='status_nodata'>&nbsp;</div>Database</li>
        <li><div class='status_nodata'>&nbsp;</div>Galaxy</li></ul>
    </div>
    <div id="volume_detail"></div>
    <div id="fs_detail"></div>
    <div id="log_container_header">
        <h3>Cluster status log</h3>
        <div id="log_container_header_img"></div>
    </div>
    <div id="log_container_body">
	<ul>
	</ul>
    </div>
</div>

## ****************************************************************************
## ******************************** Javascript ********************************
## ****************************************************************************

<script type="text/javascript">
var instances = Array();
var cluster_status = "OFF";
var fs_det_vis = false;
var last_log = 0;
var click_timeout = null;
var use_autoscaling = null;
var as_min = 0; //min number of instances autoscaling should maintain
var as_max = 0; //max number of instances autoscaling should maintain
</script>

<script type='text/javascript' src="${h.url_for('/static/scripts/jquery.tipsy.js')}"></script>
<script type='text/javascript' src="${h.url_for('/static/scripts/cluster_canvas.js')}"> </script>
<script type='text/javascript' src="${h.url_for('/static/scripts/inline_edit.js')}"> </script>
<script type="text/javascript">

function fixForms(){
    $('form').submit( function(event){
        $.post($(this).attr('action'), $(this).serialize());
        event.preventDefault();
        hidebox();
        update();
    });
	$('#volume_config')
}

function scrollLog(){
    if ($("#log_container_body").attr("scrollHeight") <= ($("#log_container_body").scrollTop() + $("#log_container_body").height() + 100)){
        $('#log_container_body').animate({
            scrollTop: $("#log_container_body").attr("scrollHeight") + 100
        }, 1000);
    }
}

function toggleVolDialog(){
	if ($('#volume_config').is(":visible")){
		$('#volume_config').hide();
		$('#voloverlay').hide();
	}else{
		$('#voloverlay').show();
		$('#volume_config').show();
	}
}

function hidebox(){
	$('.box').hide();
	$('.overlay').hide();
	$('.cluster_scale_popup').hide();
	$('.action-button.button-clicked').removeClass('button-clicked');
	$('#popupoverlay').hide();
	$('#volume_expand_popup').hide();
	$('#power_off').hide();
	$('#overlay').hide();
}

function update(){
    $.getJSON('/cloud/instance_state_json', 
		function(data) {
			if (data){
		        $('#status').html(data.instance_state);
		        $('#dns').attr("href", data.dns);
				if (data.dns == '#'){
					$('#dns').addClass('ab_disabled');
			        $('#dns').attr("target", '');
				}else{
					$('#dns').removeClass('ab_disabled');
			        $('#dns').attr("target", '_blank');
				}
				if (data.instance_status.requested == '0'){
					$('#scale_down_button').addClass('ab_disabled');
					$('#scale_down_button > img').hide();
				}else{
					$('#scale_down_button').removeClass('ab_disabled');
					$('#scale_down_button > img').show();
				}
				$('#status-idle').text( data.instance_status.idle );
		        $('#status-available').text( data.instance_status.available );
		        $('#status-total').text( data.instance_status.requested );
				$('#du-total').text(data.disk_usage.total);
				$('#du-used').text(data.disk_usage.used);
				$('#du-pct').text(data.disk_usage.pct);
				$('#snap-progress').text(data.snapshot.progress);
				$('#snap-status').text(data.snapshot.status);
				// DBTODO write generic services display
				$('#data-status').removeClass('status_nodata status_green status_red status_yellow').addClass('status_'+data.data_status);
				$('#app-status').removeClass('status_nodata status_green status_red status_yellow').addClass('status_'+data.app_status);
		        // $('#status_svcs').html(
		        //     "<ul><li class='fs_det_clicker'><div class='status_" + data.services.fs + "'>&nbsp;</div>Filesystems</li>\
		        //     <li><div class='status_" + data.services.pg + "'>&nbsp;</div>Database</li>\
		        //     <li><div class='status_" + data.services.sge + "'>&nbsp;</div>Scheduler</li>\
		        //     <li><div class='status_" + data.services.galaxy + "'>&nbsp;</div>Galaxy</li></ul>"
		        //     );
		        fsdet = "<ul>";
		        for (i = 0; i < data.all_fs.length; i++){
		            fsdet += "<li><div class='status_" + data.all_fs[i][1] + "'>&nbsp;</div>" + data.all_fs[i][0] + "</li>";
		        }
		        fsdet += "</ul>";
		        $('#fs_detail').html(fsdet);
		        cluster_status = data.cluster_status;
				if (data.autoscaling.use_autoscaling==true) {
					// $('#autoscaling_status').text('on')
					// $('#toggle_autoscaling_link').text('off')
					use_autoscaling = true;
					as_min = data.autoscaling.as_min
					as_max = data.autoscaling.as_max
					$('#scale_up_button').addClass('ab_disabled');
					$('#scale_up_button > img').hide();
					$('#scale_down_button').addClass('ab_disabled');
					$('#scale_down_button > img').hide();
				} else {
					// $('#autoscaling_status').text('off')
					// $('#toggle_autoscaling_link').text('on')
					use_autoscaling = false;
					as_min = 0
					as_max = 0
					$('#scale_up_button').removeClass('ab_disabled');
					$('#scale_up_button > img').hide();
					$('#scale_down_button').removeClass('ab_disabled');
					$('#scale_down_button > img').hide();
				}
				
			}
        });
    $.getJSON('/cloud/log_json',
		{l_log : last_log},
		function(data) {
			if (data){
				if(data.log_messages.length > 0){
					// Check to make sure the log isn't huge (1000? 5000?) and truncate it first if it is.
					var loglen = $('#log_container_body>ul>li').size();
					if (loglen > 200){
						$('#log_container_body>ul>li:lt(' +(loglen - 100)+')').remove();
						$('#log_container_body>ul').prepend('<li>The log has been truncated to keep up performance.  The <a href="/cloud/log/">full log is available here</a>. </li>');
					}
					last_log = data.log_cursor;
					var to_add = "";
					for (i = 0; i < data.log_messages.length; i++){
						to_add += "<li>"+data.log_messages[i]+"</li>";
					}
					$('#log_container_body>ul').append(to_add);
				}
			}
	});
    scrollLog();
	window.setTimeout(update, 5000);
}

$(document).ready(function() {
	var initial_cluster_type = '${initial_cluster_type}';
	var permanent_storage_size = ${permanent_storage_size};
    $('#stop-button').click(function(){
		$('#overlay').show();
		$('#power_off').show();
    });
    $('#scale_up_button').click(function(){
		$('.cluster_scale_popup').hide();
		$('.action-button.button-clicked').removeClass('button-clicked');
		$('#popupoverlay').show();
		$('#scale_up_button').addClass('button-clicked');
		$('#cluster_scale_up_popup').show();
	});
    $('#scale_down_button').click(function(){
		if ($('#scale_down_button').hasClass('ab_disabled')){
			return;
		}else{
			$('.cluster_scale_popup').hide();
			$('.action-button.button-clicked').removeClass('button-clicked');
			if (instances.length > 0) {
				$('#scale_down_button').addClass('button-clicked');
				$('#popupoverlay').show();
				$('#cluster_scale_down_popup').show();
	        }
		}
    });
    $('#expand_vol').click(function(){
		$('#overlay').show();
		$('#volume_expand_popup').show();
    });
	$('#overlay').click(function(){
		hidebox();
	});
	$('#toggle_extra_startup_options').click(function(){
		// $('#toggle_extra_startup_options_cont').hide();
		// $('#extra_startup_options').show();
		if ($('#extra_startup_options').is(":visible")){
			$('#extra_startup_options').hide();
			$('#toggle_extra_startup_options').text('Show more startup options')
		}else{
			$('#extra_startup_options').show();
			$('#toggle_extra_startup_options').text("Hide extra options");
		}
	});
	$('#popupoverlay').click(function(){
		$('.cluster_scale_popup').hide();
		$('#volume_expand_popup').hide();
		$('.action-button.button-clicked').removeClass('button-clicked');
		$('#popupoverlay').hide();
	})
    $('.boxclose').click(function(){
        hidebox();
    });
    $('#log_container_body').hide();
    $('#log_container_header').click(function() {
        if ($('#log_container_body').is(":hidden")){
			$('#log_container_header_img').css('background', 'transparent url(/cloud/static/images/plus_minus.png) no-repeat top right' );
			$('#log_container_header').addClass('clicked');
            $('#log_container_body').slideDown('fast');
        } else {
			$('#log_container_header_img').css('background', 'transparent url(/cloud/static/images/plus_minus.png) no-repeat top left' );
            $('#log_container_body').slideUp('fast', function(){
				$('#log_container_header').removeClass('clicked');
			});   
        }
        return false;
    });
	// console.log("CTC: %s" % initial_cluster_type)
    $('#initial_volume_config_form').submit( function(event) {
        cluster_status = "STARTING";
        $.post('/cloud/root/initialize_cluster', $("#initial_volume_config_form").serialize());
        event.preventDefault();
		$('#initial_volume_config_form').hide('fast');
        hidebox();
        update();
    });
    $('#power_cluster_off_form').submit( function(event) {
        cluster_status = "OFF";
        $('#main_text').html("<h4>Important:</h4><p>This cluster is terminating.  Please wait for all services to stop and for all nodes to be removed, and then terminate the master instance from the AWS console.</p>");
        $.post('/cloud/root/kill_all', $("#power_cluster_off_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('#expand_user_data_volume').submit( function(event) {
        $.post('/cloud/root/expand_user_data_volume', $("#expand_user_data_volume").serialize());
        event.preventDefault();
		$('#volume_expand_popup').hide('fast');
        hidebox();
        update();
    });
    $('#add_instances_form').submit( function(event) {
        $.post('/cloud/root/add_instances', $("#add_instances_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('#remove_instances_form').submit( function(event) {
        $.post('/cloud/root/remove_instances', $("#remove_instances_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('#turn_autoscaling_on_form').submit( function(event) {
        $.post('/cloud/root/toggle_autoscaling', $("#turn_autoscaling_on_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('#turn_autoscaling_off_form').submit( function(event) {
        $.post('/cloud/root/toggle_autoscaling', $("#turn_autoscaling_off_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('#adjust_autoscaling_form').submit( function(event) {
        $.post('/cloud/root/adjust_autoscaling', $("#adjust_autoscaling_form").serialize());
        event.preventDefault();
        hidebox();
        update();
    });
    $('.fs_det_clicker').click(function(){
        if (fs_det_vis == true){
			clearTimeout(click_timeout);
            $('#fs_detail').hide('fast');
            fs_det_vis = false;
        }
        else{
			$('#fs_detail').show('fast');
			click_timeout = setTimeout(function(){
				if (fs_det_vis == true){
					$('#fs_detail').hide('fast');
					fs_det_vis = false;
				}
				}, 5000);
			fs_det_vis = true;
        }
    });
    
    // Form validation
    var number_nodes = new LiveValidation('number_nodes', { validMessage: "OK", wait: 300, insertAfterWhatNode: 'number_nodes_vtag' } );
    number_nodes.add( Validate.Numericality, { minimum: 1, onlyInteger: true } );
    if (permanent_storage_size == 0) {
        var permanent_storage_size = new LiveValidation('g_pss', { validMessage: "OK", wait: 300, insertAfterWhatNode: 'g_pss_vtag' } );
        permanent_storage_size.add( Validate.Numericality, { minimum: 1, maximum: 1000, onlyInteger: true } );
        var permanent_storage_size = new LiveValidation('d_pss', { validMessage: "OK", wait: 300, insertAfterWhatNode: 'd_pss_vtag' } );
        permanent_storage_size.add( Validate.Numericality, { minimum: 1, maximum: 1000, onlyInteger: true } );
    }
	
	var expanded_storage_size = new LiveValidation('new_vol_size', { validMessage: "OK", wait: 300 } );
    expanded_storage_size.add( Validate.Numericality, { minimum: 1, maximum: 1000 } );
	
	var autoscaling_min_bound = new LiveValidation('as_min', { validMessage: "OK", wait: 300 } );
    autoscaling_min_bound.add( Validate.Numericality, { minimum: 0, maximum: 20, onlyInteger: true } );
	var autoscaling_max_bound = new LiveValidation('as_max', { validMessage: "OK", wait: 300 } );
    autoscaling_max_bound.add( Validate.Numericality, { minimum: 0, maximum: 20, onlyInteger: true } );
    
	$('#as_min').change(function(){
		autoscaling_max_bound.validations[0].params.minimum = $('#as_min').val();
	});
	$('#as_max').change(function(){
		autoscaling_min_bound.validations[0].params.maximum = $('#as_max').val();
	});
	
	// FIXME: Is there a better way of doing this check than repeating all the code from the preceeding validation?
	var autoscaling_min_bound = new LiveValidation('as_min_adj', { validMessage: "OK", wait: 300 } );
    autoscaling_min_bound.add( Validate.Numericality, { minimum: 0, maximum: 20, onlyInteger: true } );
	var autoscaling_max_bound = new LiveValidation('as_max_adj', { validMessage: "OK", wait: 300 } );
    autoscaling_max_bound.add( Validate.Numericality, { minimum: 0, maximum: 20, onlyInteger: true } );
	$('#as_min_adj').change(function(){
		autoscaling_max_bound.validations[0].params.minimum = $('#as_min_adj').val();
	});
	$('#as_max_adj').change(function(){
		autoscaling_min_bound.validations[0].params.maximum = $('#as_max_adj').val();
	});
	
	
    if (initial_cluster_type == 'None') {
		toggleVolDialog();
	}
	update();
});

</script>
    </div>
</%def>
