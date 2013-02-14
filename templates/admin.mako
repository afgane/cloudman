<%inherit file="/base_panels.mako"/>
<%def name="main_body()">
<div ng-app="cloudman">
	<div ng-controller="cmAlertController">
		<alert ng-repeat="alert in getAlerts()" type="alert.type" close="closeAlert(alert)">{{alert.msg}}</alert>
	</div>
	<!-- 
	<div id="msg_box" class="info_msg_box" style="margin-top: -25px; min-height: 16px">
		<span id="msg" class="info_msg_box_content" style="display: none"></span>
	</div>
	 -->
	<%include file="bits/messages.htm" />

	<header>
		<h2>CloudMan Admin Console</h2>
		<div>
			<span class="lead">
				This admin panel is a convenient way to gain insight into the status
				of individual CloudMan services as well as to control those services.
			</span>
			<p class="text-warning">Services should not be manipulated unless absolutely
				necessary.
				Please keep in mind that the actions performed by these service-control
				'buttons' are basic in that they assume things will operate as
				expected.
				In other words, minimal special case handling for recovering services
				exists. Also note that clicking on a service action button will
				initiate the action; there is no additional confirmation required.
			</p>
		</div>
	</header>

	<section id="service_controls" ng-controller="ServiceController">
		<div>
			<h3>Service controls</h3>
		</div>
		<p>
			Use these controls to administer individual application services
			managed by CloudMan.
			Currently running a '<a href="http://wiki.g2.bx.psu.edu/Admin/Cloud" target='_blank'>${initial_cluster_type}</a>' type of cluster.
		</p>

		<table class="table">
			<thead>
				<tr>
					<th></th>
					<th>Service name</th>
					<th>Status</th>
					<th colspan="6"></th>
				</tr>
			</thead>
			<tbody ng-repeat="svc in getServices()" ng-switch on="svc.svc_name">
				<tr id="service_row_{{svc.svc_name}}" style="text-align:left">
					<td>
						<a ng-click="expandServiceDetails()" ng-show="svc.requirements"><i ng-class="{'icon-caret-right': !is_service_visible(), 'icon-caret-down': is_service_visible()}"></i></a>
					</td>
					<td ng-bind="svc.svc_name" />
					<td ng-bind="svc.status" />
					<td ng-repeat="action in svc.actions">
						<a ng-href="{{action.action_url}}" ng-bind="action.name" ng-click="performServiceAction($event, action)"></a>
					</td>
					<td colspan=4 />
				</tr>
				<tr ng-switch-when="Galaxy" ng-show="is_service_visible()">
					<td></td>
					<td colspan="9" ng-controller="GalaxyController">
						<%include file="bits/galaxy_controls.htm" />
					</td>
				</tr>
				<tr id="service_detail_row_{{svc.svc_name}}" ng-show="is_service_visible()">
					<td></td>
					<td colspan="9">
						<form name="form_assigned_service" ng-controller="AssignedServiceController" ng-switch on="is_editing">
							<div ng-switch-when="false">
								<strong>Required Services:</strong>
								<table width="600px" style="margin:10px 0; text-align:left">
									<thead>
										<tr>
											<th width="30%">Requirement Name</th>
											<th width="20%">Type</th>
											<th width="20%">Assigned Service</th>
										</tr>
									</thead>
									<tr ng-repeat="req in record.requirements">
										<td>{{req.display_name}}</td>
										<td>{{req.type}}</td>
										<td>{{req.assigned_service}}</td>
									</tr>
								</table>
								<button class="btn btn-small btn-warning" ng-click="beginEdit(record)"><i class="icon-edit"></i>&nbsp;Reassign services</button>
							</div>
							<div ng-switch-when="true">
								<strong>Required Services:</strong>
								<table width="600px" style="margin:10px 0; text-align:left">
									<thead>
										<tr>
											<th width="30%">Requirement Name</th>
											<th width="20%">Type</th>
											<th width="20%">Assigned Service</th>
											<th width="20%">Copy Data Across</th>
										</tr>
									</thead>
									<tr ng-repeat="req in record.requirements">
										<td>{{req.display_name}}</td>
										<td>{{req.type}}</td>
										<td>
											<div ng-switch on="req.type">
												<div ng-switch-when="APPLICATION">{{req.assigned_service}}</div>
												<div ng-switch-when="FILE_SYSTEM">
													<select id="assigned_fs_{{svc.name}}_{{req.role}"
														ng-model="req.assigned_service"
														ng-options="fs.name as fs.name for fs in getAvailableFileSystems()" />
												</div>
											</div>
										</td>
										<td>
											<input ui-if="req.type=='FILE_SYSTEM'" type="checkbox" ng-model="req.copy_across" value="true" />
										</td>
									</tr>
								</table>
								<button class="btn btn-small btn-warning" ng-click="save(record, '${h.url_for(controller='root', action='reassign_services')}')" ng-disabled="form_assigned_service.$invalid || isUnchanged(record)"><i class="icon-save"></i>&nbsp;Update</button>
								<button class="btn btn-small" ng-click="cancelEdit(record)"><i class="icon-undo"></i>&nbsp;Cancel</button>
							</div>
						</form>						
					</td>
				</tr>
			</tbody>
		</table>
	</section>		
		
	<section id="file_systems_redone" ng-controller="FileSystemController">
		<div>
			<h3>File systems</h3>
		</div>
		<p>
			Use these controls to administer individual file systems
			managed by CloudMan.
		</p>
		<table class="table">
	        <thead>
	            <tr class="filesystem-tr">
	                <th class="fs-td-20pct">Name</th>
	                <th class="fs-td-15pct">Status</th>
	                <th class="fs-td-20pct">Usage</th>
	                <th class="fs-td-15pct">Controls</td>
	                <th colspan="2"></th>
	            </tr>
	        </thead>
	        <tbody>
	        	<tr ng-repeat="fs in getFileSystems()">
			        <td>{{fs.name}}</td>
			        <td ng-switch on="fs.status">
			        	<p ng-switch-when="Running" class="text-success">{{fs.status}}</p>
			        	<p ng-switch-when="Error" class="text-error">{{fs.status}}</p>
			        	<p ng-switch-default class="text-warning">{{fs.status}}</p>
			        </td>
			        <td>
				        <!-- // Only display usage when the file system is 'Available' -->
			            <meter id="fs-meter-{{fs.name}}" class="meter_file_system_space_usage" min="0" max="100" value="{{fs.size_pct}}" high="85" ng-show="is_ready_fs(fs)" display-value="{{fs.size_used}}/{{fs.size}} ({{fs.size_pct}}%)" />
			            <span ng-show="is_snapshot_in_progress(fs)">
			                Snapshot status: {{fs.snapshot_status}}; progress: {{fs.snapshot_progress}}
			            </span>
					</td>
			        <td>
			            <!-- // Enable removal while a file system is 'Available' or 'Error' -->
			            <a ng-show="!is_snapshot_in_progress(fs)" class="fs-remove icon-button" id="fs-{{fs.name}}-remove"
			               title="Remove this file system" ng-click="remove_fs($event, fs)"></i></a>
			            <!--// Only display additional controls when the file system is 'Available'-->
			            <!-- It only makes sense to persist DoT, snapshot-based file systems -->
						<a ng-show="is_persistable_fs(fs)" class="fs-persist icon-button" id="fs-{{fs.name}}-persist"
			                        title="Persist file system changes" ng-click="persist_fs($event, fs)"></a>
			            <!-- It only makes sense to resize volume-based file systems -->
						<a ng-show="is_resizable_fs(fs)" class="fs-resize icon-button" id="fs-{{fs.name}}-resize" href="#" ng-click="resize_fs($event, fs)" title="Increase file system size"></a>
			        </td>
			        <td>
			        	<!-- <a class="fs-details" details-box="fs-{{fs.name}}-details" data-toggle="popover" data-placement="right" ng-mouseover="prepareToolTip(fs)" title="Filesystem details">Details</a>
			        	-->
			        	
			        	<a class="fs-details" details-box="fs-{{fs.name}}-details" title="Filesystem details" ng-click="toggleDetailView($event, fs)">Detail</a>
			        	<span id="fs-details-popover-{{fs.name}}" popover-placement="right" cm-popover popover-animation="true" style="visibility:hidden"></span>
			        </td>
			        <td></td>
				</tr>
	        </tbody>
		</table>
	</section>	

	<section id="add_filesystem" ng-controller="AddFSController">
		<div class="row-fluid" id="fs_add_section">
			<div class="span12" id="app_service_header_row">
			
				<!-- Add new button row -->
				<div class="row-fluid" ng-show="!is_adding_fs">
					<div class="span12">
						<button class="btn" ng-click="showAddNewFSForm()"><i class="icon-plus"></i>&nbsp;Add New</button>
					</div>
				</div>
				
				<!-- Add File System Form -->
				<div class="row-fluid" ng-show="is_adding_fs">
					<div class="span12">
						<form class="fs-add-form form-inline" ng-switch on="selected_device">
						
							<!-- Intro and close button -->				
							<span class="help-block">
									<button type="button" class="close" ng-click="hideAddNewFSForm()">&times;</button>
							    	Through this form you may add a new file system and make it available
					            	to the rest of this CloudMan platform.
					         </span>
							 
							<!-- Device selection -->
							<fieldset>
								<strong>File system source or device:</strong>
								<label class="radio">
							      <input type="radio" name="fs_kind" value="bucket" ng-model="selected_device" /> Bucket
							    </label>
							    
							    <label class="radio">
							      <input type="radio" name="fs_kind" value="volume" ng-model="selected_device" /> Volume
							    </label>
							    
							    <label class="radio">
							      <input type="radio" name="fs_kind" value="snapshot" ng-model="selected_device" /> Snapshot
							    </label>
							    
							    <label class="radio">
							      <input type="radio" name="fs_kind" value="new_volume" ng-model="selected_device" /> New volume
							    </label>
							    
							    <label class="radio">
							      <input type="radio" name="fs_kind" value="nfs" ng-model="selected_device" /> NFS
							    </label>
						    </fieldset>						        

							<!-- Device selection -->
							<fieldset ng-switch-when="bucket" class="form-horizontal">
								<div class="control-group">
									<label class="control-label" for="bucket_name">Bucket name:</label>
								    <div class="controls">
								      <input type="text" id="bucket_name" name="bucket_name" placeholder="e.g., 1000genomes"/>
								      <span class="help-inline">(AWS S3 buckets only)</span>
								    </div>					    
								</div>
								<div class="control-group">
									<label class="control-label" for="bucket_fs_name">File system name:</label>
								    <div class="controls">
								      <input type="text" id="bucket_fs_name" name="bucket_fs_name">
								      <span class="help-inline">(no spaces, alphanumeric characters only)</span>
								    </div>
								 </div>
								 
								 <p> It appears you are not running on the AWS cloud. CloudMan supports
						                    using only buckets from AWS S3. So, if the bucket you are trying to
						                    use is NOT PUBLIC, you must provide the AWS credentials that can be
						                    used to access this bucket. If the bucket you are trying to use
						                    IS PUBLIC, leave below fields empty.</p>
						                    <table><tr>
						                        <td><label for"bucket_a_key">AWS access key: </label></td>
						                        <td><input type="text" id="bucket_a_key" name="bucket_a_key" size="50" /></td>
						                    </tr><tr>
						                        <td><label for"bucket_s_key">AWS secret key: </label></td>
						                        <td><input type="text" id="bucket_s_key" name="bucket_s_key" size="50" /></td>
						                    </tr></table>
						    </fieldset>		
						    
							<!-- Volume form details -->
							<div class="row-fluid" ng-switch-when="volume">
								<div class="span12">
									<table><tr>
					                    <td><label for="vol_id">Volume ID: </label></td>
					                    <td><input type="text" size="20" name="vol_id" id="vol_id"
					                        placeholder="e.g., vol-456e6973"/></td>
					                    </tr><tr>
					                    <td><label for="vol_fs_name">File system name: </label></td>
					                    <td><input type="text" size="20" name="vol_fs_name" id="vol_fs_name">
					                    (no spaces, alphanumeric characters only)</td>
					                </tr></table>
								</div>
							</div>

							<!-- Snapshot form details -->
							<div class="row-fluid" ng-switch-when="snapshot">
								<div class="span12">
									<table><tr>
					                    <td><label for="snap_id">Snapshot ID: </label></td>
					                    <td><input type="text" size="20" name="snap_id" id="snap_id"
					                        placeholder="e.g., snap-c21cdsi6"/></td>
					                    </tr><tr>
					                    <td><label for="snap_fs_name">File system name: </label></td>
					                    <td><input type="text" size="20" name="snap_fs_name" id="snap_fs_name">
					                    (no spaces, alphanumeric characters only)</td>
					                </tr></table>
								</div>
							</div>

							<!-- New volume form details -->
							<div class="row-fluid" ng-switch-when="new_volume">
								<div class="span12">
									<table><tr>
					                    <td><label for="new_disk_size">New file system size: </label></td>
					                    <td><input type="text" size="20" name="new_disk_size" id="new_disk_size"
					                        placeholder="e.g., 100"> (minimum 1GB, maximum 1000GB)</td>
					                    </tr><tr>
					                    <td><label for="new_vol_fs_name">File system name: </label></td>
					                    <td><input type="text" size="20" name="new_vol_fs_name" id="new_vol_fs_name">
					                    (no spaces, alphanumeric characters only)</td>
					                </tr></table>
								</div>
							</div>

							<!--   NFS form details -->
							<div class="row-fluid" ng-switch-when="nfs">
								<div class="span12">
									<table><tr>
					                    <td><label for="nfs-server">NFS server address: </label></td>
					                    <td><input type="text" size="20" name="nfs_server" id="nfs_server"
					                        'placeholder="e.g., 172.22.169.17:/nfs_dir"></td>
					                    </tr><tr>
					                    <td><label for="nfs_fs_name">File system name: </label></td>
					                    <td><input type="text" size="20" name="nfs_fs_name" id="nfs_fs_name">
					                    (no spaces, alphanumeric characters only)</td>
					                </tr></table>
								</div>
							</div>

							<!--   Delete FS option -->
							<div class="row-fluid">
								<div class="span12">
									<span class="inline">
									<input type="checkbox" name="dot" id="add-fs-dot-box"><label for="add-fs-dot-box">
	                				If checked, the created disk <strong>will be deleted</strong> upon cluster termination</label>
	                				</span>
								</div>
							</div>
							
							<!--  Persist option -->
							<div class="row-fluid">
								<div class="span12">
									<input type="checkbox" name="persist" id="add-fs-persist-box">
					                <label for="add-fs-persist-box">If checked,
					                the created disk <strong>will be persisted</strong> as part of the cluster configuration
					                and thus automatically added the next time this cluster is started</label>
								</div>
							</div>
							
							<!--  Save or cancel option -->
							<div  class="row-fluid">
								<div class="span12">
									<input type="submit" class="btn btn-primary" value="Add new file system"/>
	                				or <a ng-click="hideAddNewFSForm()">cancel</a>
								</div>
							</div>
									
						</form>
					</div>
				</div>
			</div>
		</div>
	</section>		

	<section id="system_controls" ng-controller="SystemController">
		<h3>System controls</h3>
		<p>
			Use these controls to administer CloudMan itself as well as the
			underlying system.
		</p>
		<ul>
			<li>
				Command used to connect to the instance:
				<code>
					ssh -i
					<em>[path to ${key_pair_name} file]</em>
					ubuntu@${ip}
				</code>
			</li>
			<li>
				Name of this cluster's bucket: ${bucket_cluster}
				%if cloud_type == 'ec2':
				(
				<a id='cloudman_bucket' href="https://console.aws.amazon.com/s3/home?#"
					target="_blank">access via AWS console</a>
				)
				%endif
				<span class="help_info">
					<span class="help_link">Bucket info</span>
					<div class="help_content" style="display: none">
						Each CloudMan cluster has its configuration saved in a persistent
						data repository. This repository is read at cluster start and it
						holds all the data required to restart this same cluster. The
						repository is stored under your cloud account and is accessible
						only with your credentials.
						<br />
						In the context of AWS, S3 acts as a persistent data repository
						where
						all the data is stored in an S3 bucket. The name of the bucket
						provided here corresponds to the current cluster and is provided
						simply as a reference.
					</div>
				</span>
				<li>
					<a id='show_user_data' ng-click="showUserData($event, '${h.url_for(controller='root', action='get_user_data')}')">Show current user data</a>
				</li>
				<li>
					<a id='cloudman_log'
						href="${h.url_for(controller='root', action='service_log')}?service_name=CloudMan">Show CloudMan log</a>
				</li>
			</li>
			<li>
				<a class="action" href="${h.url_for(controller='root', action='toggle_master_as_exec_host')}"
				ng-click="toggleMasterAsExecHost($event, '${h.url_for(controller='root', action='toggle_master_as_exec_host')}')">
					<span ui-if="getMasterIsExecHost()">Switch master not to run jobs</span>
					<span ui-if="!getMasterIsExecHost()">Switch master to run jobs</span>
				</a>
				<span class="help_info">
					<span class="help_link">What will this do?</span>
					<div class="help_content" style="display: none">
						By default, the master instance running all the services is also
						configured to
						execute jobs. You may toggle this functionality here. Note that if job
						execution
						on the master is disabled, at least one worker instance will be
						required to
						run any jobs.
					</div>
				</span>
			</li>
			<li>
				<a class='action'
					href="${h.url_for(controller='root', action='store_cluster_config')}">Store current cluster configuration</a>
				<span class="help_info">
					<span class="help_link">What will this do?</span>
					<div class="help_content" style="display: none">
						Each CloudMan cluster has its own configuration. The state of
						this cofiguration is saved as 'persistent_data.yaml'
						file in the cluster's bucket. Saving of this file
						happens automatically on cluster configuration change.
						This link allows you to force the update of the cluster
						configuration and capture its current state.
					</div>
				</span>
			</li>
			<li>
				<a class='action' href="${h.url_for(controller='root', action='reboot')}">Reboot master instance</a>
				<span class="help_info">
					<span class="help_link">What will this do?</span>
					<div class="help_content" style="display: none">
						Reboot the entire system. This will shut down all of the
						services and reboot the machine. If there are any worker
						nodes assciated with the cluster they will be reconnected
						to after the system comes back up.
					</div>
				</span>
			</li>
			<li>
				<a class='action'
					href="${h.url_for(controller='root', action='recover_monitor')}">Recover monitor</a>
				<span class="help_info">
					<span class="help_link">What will this do?</span>
					<div class="help_content" style="display: none">
						Try to (re)start CloudMan service monitor thread, which is
						responsible for monitoring the status of all of the other
						services. This should only be used if the CloudMan user
						interface becomes unresponsive or during debugging.
					</div>
				</span>
			</li>
			<li>
				<a class='action'
					href="${h.url_for(controller='root', action='recover_monitor')}?force=True">Recover monitor *with Force*</a>
				<span class="help_info">
					<span class="help_link">What will this do?</span>
					<div class="help_content" style="display: none">
						Start a new CloudMan service monitor thread regardless
						of whether one already exists.
					</div>
				</span>
			</li>
		</ul>
	</section>

    ## ****************************************************************************
    ## **************************** Script Templates ******************************
    ## ****************************************************************************

    <script type="text/template" id="fs-details-popover-template">
        <table>
        <tr><th>Name:</th><td>{{ fs.name }}</td></tr>
        <tr><th>Bucket name:</th><td>{{ fs.bucket_name }}</td></tr>
        <tr><th>Status:</th><td>{{ fs.status }}</td></tr>
        <tr><th>Mount point:</th><td>{{ fs.mount_point }}</td></tr>
        <tr><th>Kind:</th><td>{{ fs.kind }}</td></tr>
		<tr><th>Volume:</th><td>{{ fs.volume_id }}</td></tr>
		<tr><th>Device:</th><td>{{ fs.device }}</td></tr>
		<tr><th>From snapshot:</th><td>{{ fs.from_snap }}</td></tr>
		<tr><th>NFS server:</th><td>{{ fs.nfs_server }}</td></tr>
        <tr><th>Size (used/total):</th><td>{{ fs.size_used }}/{{ fs.size }} ({{ fs.size_pct }}%)</td></tr>
        <tr><th>Delete on termination:</th><td>{{ fs.DoT }}</td></tr>
        <tr><th>Persistent:</th><td>{{ fs.persistent }}</td></tr>
        </table>
    </script>

    <script type="text/template" id="fs-resize-dialog-template">
    	<form id="fs_resize_form" action="${h.url_for(controller='root',action='expand_user_data_volume')}" method="POST">
    	<div class="modal-header" style="padding: 12px 12px 12px 12px">
    		<div class="modal-header">
		    	<h3>Resize File System</h3>
	    	</div>
	        <div class="modal-body" >
		        <p>
		            Through this form you may increase the disk space available to this file system.
		            Any services using this file system <strong>WILL BE STOPPED</strong>
		            until the new disk is ready, at which point they will all be restarted. Note
		            that This may result in failure of any jobs currently running. Note that the new
		            disk size <strong>must be larger</strong> than the current disk size.
		            <p>During this process, a snapshot of your data volume will be created,
		            which can optionally be left in your account. If you decide to leave the
		            snapshot for reference, you may also provide a brief note that will later
		            be visible in the snapshot's description.</p>
		        </p>    
	            <label>New disk size (minimum {{ fs.size }}B,
	            maximum 1000GB)</label>
	            <div id="permanent_storage_size">
	                <input type="text" name="new_vol_size" id="new_vol_size"
	                placeholder="Greater than {{ fs.size }}B" size="25" ng-model="resize_details.new_vol_size" />
	                {{ resize_details.new_vol_size}}
	            </div>
	            <label>Note</label>
	            <div id="permanent_storage_size">
	                <input type="text" name="vol_expand_desc" id="vol_expand_desc" value=""
	                placeholder="Optional snapshot description" size="50" ng-model="resize_details.vol_expand_desc" /><br/>
	            </div>
	            <label>or delete the created snapshot after filesystem resizing?</label>
	            <input type="checkbox" name="delete_snap" id="delete_snap" ng-model="resize_details.delete_snap" /> If checked,
	            the created snapshot will not be kept.
	        </div>
	        <div class="modal-footer">
	        	<button ng-click="resize($event)" class="btn btn-warning" >Resize {{ fs.name }} file system</button>
	      		<button ng-click="cancel($event)" class="btn" >Cancel</button>  
	        </div>
	        <input name="fs_name" type="hidden" value="{{fs.name}}" />
        </div>
        </form>
    </script>
    
    <script type="text/template" id="fs-delete-dialog-template">
    	<form id="fs_remove_form" action="${h.url_for(controller='root',action='manage_service')}?service_name={{fs.name}}&to_be_started=False&is_filesystem=True" method="GET">
    		<div class="modal-header">
		    	<h3>Remove file system: {{ fs.name }}?</h3>
	    	</div>
	        <div class="modal-body" >
		        <p>
				Removing this file system will first stop any services that require this file system.
				Then, the file system will be unmounted and the underlying device disconnected from this instance.
		        </p>    
	        <div class="modal-footer">
	        	<button ng-click="confirm($event, 'confirm')" class="btn btn-warning" >Remove</button>
	      		<button ng-click="cancel($event, 'cancel')" class="btn" >Cancel</button>  
	        </div>
        </form>
    </script> 
    
    <script type="text/template" id="fs-persist-dialog-template">
    	<form id="fs_persist_form" action="${h.url_for(controller='root', action='update_file_system')}?fs_name={{fs.name}}" method="GET">
    		<div class="modal-header">
		    	<h3>Persist file system: {{ fs.name }}?</h3>
	    	</div>
	        <div class="modal-body" >
		        <p>
				If you have made changes to the <em>{{ fs.name }}</em> file system and would like to persist the changes
                across cluster invocations, it is required to persist those
                changes.
                </p>
                <p>
                <em>What will happen next?</em>
                </p>
                <p>
                Persisting file system changes requires that any services running on the
                file system be stopped and the file system unmounted. Then, a
                snapshot of the underlying volume will be created and any services
                running on the file system started back up. Note that depending
                on the amount of changes you have made to the file system, this
                process may take a while.
		        </p>    
	        <div class="modal-footer">
	        	<button ng-click="confirm($event, 'confirm')" class="btn btn-primary" >Confirm</button>
	      		<button ng-click="cancel($event, 'cancel')" class="btn btn-primary" >Cancel</button>  
	        </div>
        </form>
    </script>
    
    ## ****************************************************************************
    ## ******************************** Javascript ********************************
    ## ****************************************************************************
    <script type='text/javascript'>
        // Place URLs here so that url_for can be used to generate them
        var get_cloudman_system_status_url = "${h.url_for(controller='root',action='get_cloudman_system_status')}";
        var cloud_type = "${cloud_type}";
    </script>
    
    <script type='text/javascript' src="${h.url_for('/static/scripts/jquery.form.js')}"></script>
    <script type='text/javascript' src="${h.url_for('/static/scripts/admin.js')}"></script>
</div>
</%def>
