package com.nitobi.webapis.youtube
{
	import com.nitobi.webapis.youtube.event.YouTubeEvent;
	import com.nitobi.webapis.youtube.rest.GetUploadTokenAction;
	import com.nitobi.webapis.youtube.rest.GetUserVideosAction;
	import com.nitobi.webapis.youtube.rest.LoginAction;
	import com.nitobi.webapis.youtube.rest.LogoutAction;
	import com.nitobi.webapis.youtube.rest.RestAction;
	import com.nitobi.webapis.youtube.rest.UploadAction;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IEventDispatcher;
	import flash.events.TimerEvent;
	import flash.filesystem.File;
	import flash.net.FileReference;
	import flash.net.SharedObject;
	import flash.utils.Dictionary;
	import flash.utils.Timer;
	
	import mx.collections.ArrayCollection;
	import mx.collections.Sort;
	import mx.collections.SortField;


	public class YouTubeService extends EventDispatcher
	{
		
		public static var URL_FORGOT_PASSWORD:String = "http://www.youtube.com/forgot?next=/";
		public static var URL_FORGOT_USERNAME:String = "http://www.youtube.com/forgot_username?next=/";
		public static var URL_SIGNUP:String = "http://www.youtube.com/signup?next_url=/&";
		public static var URL_HELP:String = "http://www.youtube.com/t/help_gaia";
		
		public static const MAX_QUEUE_SIZE:int = 100;
		public static const MAX_FILE_SIZE:int = (1024 * 1024 * 1024); // 1 GB
		public static const ALLOWED_EXTENSIONS:String = "wmv|avi|mov|mpg|flv"; // note this must be lowercase
		
		private var localSharedObjKey:String = "YTService";
		
		private var tempCredentials:Object; // store username and password if they choose
		
		private var _loginAction:LoginAction;
		private var _logoutAction:LogoutAction;
		private var _uploadAction:UploadAction;
		private var _getUserVideosAction:GetUserVideosAction;
		private var _getUploadTokenAction:GetUploadTokenAction;
		
		private var _authToken:String;
		private var _currentUserName:String;
		
		private var _clientID:String;
		private var _devKey:String;
		
		private var _uploadQueue:ArrayCollection;
		
		private var _userVideos:ArrayCollection;
		private var _userVideoMap:Dictionary;
		
		// this will also serve as a keep-alive
		public static var TIMER_INTERVAL:int = ( 30 * 1000 ); // thirty seconds
		
		private var _refreshTimer:Timer;
		
		[Bindable]
		public var isAuthenticated:Boolean = false;
		
		[Bindable]
		public var isUploading:Boolean = false;
		
		[Bindable]
		public var uploadFileIndex:int = 0;
		
		[Bindable]
		public var totalUploads:int;
		
		[Bindable]
		public var currentFileUploadProgress:Number;
		
		[Bindable]
		public var currentlyUploadingFile:*;
		
		[Bindable]
		public var failedUploads:ArrayCollection;
		
		private var _duplicateUploads:ArrayCollection;
		
		[Bindable]
		public var processingCount:int; // the number of videos currently being processed by YouTube

		
		public function YouTubeService(target:IEventDispatcher=null)
		{
			super(target);
			_userVideoMap = new Dictionary();
			_userVideos = new ArrayCollection();
		}
		
		// Public getter/setters
		
		/**************************************************** authToken
		 */
		[Bindable]
		public function get authToken():String
		{
			return this._authToken;
		}
		
		public function set authToken(value:String):void
		{
			this._authToken = value;
		}
		
		/**************************************************** currentUserName
		 */
		[Bindable]
		public function get currentUserName():String
		{
			return this._currentUserName;
		}
		
		public function set currentUserName(value:String):void
		{
			this._currentUserName = value;
		}
		
		/**************************************************** uploadQueue
		 */
		[Bindable]
		public function set uploadQueue(value:ArrayCollection):void
		{
			_uploadQueue = value;
		}
		
		
		public function get uploadQueue():ArrayCollection
		{
			if(_uploadQueue == null)
			{
				_uploadQueue = new ArrayCollection();
			}
			return this._uploadQueue;
		}
		
		
		/**************************************************** userVideos
		 */
		[Bindable]
		public function set userVideos(value:ArrayCollection):void
		{
			this._userVideos = value;
		}
		
		public function get userVideos():ArrayCollection
		{
			return this._userVideos;
		}
		
		
		
		
		// Public Methods
		// call this before a drop operation
		public function clearDuplicateFiles():void
		{
			_duplicateUploads = null;
		}
		
		public function get duplicateUploads():ArrayCollection
		{
			if(_duplicateUploads == null)
			{
				_duplicateUploads = new ArrayCollection();
			}
			return _duplicateUploads;
		}
		
		
		// returns true if queue is full
		public function recursiveAddFile(file:File):Boolean
		{
			
			if(uploadQueue.length < MAX_QUEUE_SIZE)
			{
				if(file.isDirectory)
				{
					var dirFiles:Array = file.getDirectoryListing();
					
					for(var n:int = 0; n < dirFiles.length;n++)
					{
						var childFile:File = dirFiles[n] as File;
						if(recursiveAddFile(childFile))
						{
							return true;
						}
					}
				}
				else
				{
					if(isSupportedType(file.extension))
					{
						if(file.size > MAX_FILE_SIZE)
						{
							var errEvt:YouTubeEvent = new YouTubeEvent(YouTubeEvent.YTEVENT_FILESIZE_EXCEEDED);
							errEvt.data = file;
							dispatchEvent(errEvt);
						}
						else if(fileIsInQueue(file.url))
						{
							if(!duplicateUploads.contains(file))
							{
								duplicateUploads.addItem(file);
							}
						}
						else
						{
							addFileToQueue(file.url);
						}
					}
				}
				return false;
			}
			return true;	
		}
		
		public function fileIsInQueue(fileUrl:String):Boolean
		{
			for(var n:int = 0; n < _uploadQueue.length; n++)
			{
				if((_uploadQueue.getItemAt(n) as UserUpload).file.url == fileUrl)
				{
					return true;
				}
			}
			return false;
		}
		
		public function isSupportedType(ext:String):Boolean
		{
			return (ALLOWED_EXTENSIONS.indexOf(ext.toLowerCase()) > -1);
		}
			
		public function setCredentials(clientID:String,devKey:String):void
		{
			this._clientID = clientID;
			this._devKey = devKey;
			if(checkCredentials())
			{
				// dispatch credentials set event? -jm
			}
		}
		
		/**
		 * logout
		 */
		public function logout():void
		{
			if(isAuthenticated) // can't log out if you're not logged in
			{
				if(_logoutAction == null)
				{
					_logoutAction = new LogoutAction();
					_logoutAction.addEventListener(RestAction.REST_EVENT_ERROR,onLogoutError);
					_logoutAction.addEventListener(RestAction.REST_EVENT_SUCCESS,onLogoutSuccess);
					_logoutAction.execute();
				}
				else
				{
					throw new Error("YouTube.LogoutAction pending");
				}
			}
			processingCount = 0;
			uploadQueue = new ArrayCollection();
			userVideos = new ArrayCollection();
			_userVideoMap = new Dictionary();
			
		}
		
		private function onLogoutSuccess(evt:Event):void
		{
			cleanup();
			clearSession();
			// TODO: dispatch event
			stopRefreshTimer();
		}
		
		private function onLogoutError(evt:Event):void
		{
			cleanup();
			clearSession();
			// TODO: dispatch event
			stopRefreshTimer();
		}
		
		private function clearSession():void
		{
			authToken = "";
			currentUserName = "";
			currentlyUploadingFile = null;
			this.isAuthenticated = false;
			uploadQueue = null;
		}
		
		/**
		 * 	login
		 */
		public function login(userName:String,password:String,rememberMe:Boolean = true):void
		{
			tempCredentials = rememberMe ? {username:userName,password:password} : null;
			
			if(checkCredentials())
			{
				if(_loginAction == null)
				{
					currentUserName = userName;
					_loginAction = new LoginAction();
					_loginAction.addEventListener(RestAction.REST_EVENT_ERROR,onLoginError);
					_loginAction.addEventListener(RestAction.REST_EVENT_SUCCESS,onLoginSuccess);
					_loginAction.userName = userName;
					_loginAction.password = password;
					_loginAction.execute();
					this.isAuthenticated = false;
					dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_LOGIN_START));
				}
				else
				{
					throw new Error("YouTube.LoginAction pending");
				}
			}
		}
		
		public function onLoginSuccess(evt:Event):void
		{
			// pull out our token
			this._authToken = _loginAction.authToken;
			this.isAuthenticated = true;
			
			if(isAuthenticated && tempCredentials)
			{
				storeUserCredentials();
			}
			else
			{
				clearUserCredentials();
			}
				
			dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_LOGIN_SUCCESS));
			cleanup();
			
			refreshUserVideos();
			startRefreshTimer();
		}
		
		public function onLoginError(evt:Event):void
		{
			dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_LOGIN_ERROR));
			cleanup();
		}
		
		/**
		 * 	get user videos 
		 */
		public function refreshUserVideos():void
		{
			if(checkCredentials() && !isUploading)
			{
				if(_getUserVideosAction == null)
				{
					_getUserVideosAction = new GetUserVideosAction();
					_getUserVideosAction.addEventListener(RestAction.REST_EVENT_ERROR,onGetUserVideosError);
					_getUserVideosAction.addEventListener(RestAction.REST_EVENT_SUCCESS,onGetUserVideosSuccess);
					_getUserVideosAction.execute(authToken,_clientID,_devKey);
				}
				else
				{
					throw new Error("YouTube.GetUserVideosAction pending");
				}
			}
		}
		
		public function onGetUserVideosError(evt:Event):void
		{
			//trace("onGetUserVideosError");
			// TODO: Dispatch event
			cleanup();
		}
		

		
		public function onGetUserVideosSuccess(evt:Event):void
		{
			// update the list of user videos ...
			var totalResults:int = _getUserVideosAction.totalResults;
			var itemsPerPage:int = _getUserVideosAction.itemsPerPage;
			var startIndex:int = _getUserVideosAction.startIndex;
			
			var arr:Array = _getUserVideosAction.items;
			var procCount:int = 0;
			
			for(var n:int = 0; n < arr.length; n++)
			{
				var userVid:UserVideo = arr[n] as UserVideo;
				if(_userVideoMap[userVid.id] == null)
				{
					userVideos.addItem(userVid);
					_userVideoMap[userVid.id] = userVid;
					
				}
				else
				{	// call update so we only change properties and allow bindings to update
					_userVideoMap[userVid.id].update(userVid);
				}
				if(userVid.status == UserVideo.STATUS_PROCESSING)
				{
					procCount++;
				}
			}
			
			// need to know if we should fire an event ( after cleanup )
			var hasProcCountChanged:Boolean = (procCount != processingCount);
			processingCount = procCount;
			
			var sort:Sort = new Sort();
			sort.fields = [new SortField("published",true,true)];
			userVideos.sort = sort;
			userVideos.refresh();
			cleanup();
			
			if(hasProcCountChanged)
			{
				// dispatch event
				var procChangeEvent:YouTubeEvent = new YouTubeEvent(YouTubeEvent.YTEVENT_PROCESSING_COUNT_CHANGE);
					procChangeEvent.data = processingCount;
				dispatchEvent(procChangeEvent);
			}
		}
		
		public function addFileToQueue(filePath:String):int
		{
			if(!isUploading)
			{
				var lfi:UserUpload = UserUpload.create(filePath);
				this._uploadQueue.addItem(lfi);
			}
			else
			{
				// TODO: remove this restriction
				// trace("cannot add items to the queue while we are uploading");
			}
			return this._uploadQueue.length;
		}
		
		public function removeFileFromQueue(fileVO:*):void
		{
			var length:int = this.uploadQueue.length;
			for(var n:int = 0; n < length; n++)
			{
				var file:File = this._uploadQueue.getItemAt(n).file as File;
				if(file != null && file == fileVO.file)
				{
					this._uploadQueue.removeItemAt(n);
					break;
				}
			}
		}
		
		public function startUploading():void
		{
			if(checkCredentials() && uploadQueue.length > 0)
			{
				failedUploads = new ArrayCollection();
				this.isUploading = true;
				this.uploadFileIndex = 0;
				this.totalUploads = this.uploadQueue.length;
				uploadNextVideo();
				dispatchEvent(new Event("upload_start"));
			}
		}
		
		private function uploadNextVideo():void
		{
			if(_getUploadTokenAction == null)
			{
				if(uploadQueue.length > 0)
				{
					_getUploadTokenAction = new GetUploadTokenAction();
					currentlyUploadingFile = uploadQueue.removeItemAt(0) as UserUpload;
					_getUploadTokenAction.mediaTitle = currentlyUploadingFile.name;
					_getUploadTokenAction.addEventListener(RestAction.REST_EVENT_ERROR,onGetUploadTokenError);
					_getUploadTokenAction.addEventListener(RestAction.REST_EVENT_SUCCESS,onGetUploadTokenSuccess);
					_getUploadTokenAction.execute(authToken,_clientID,_devKey);
				}
			}
			else
			{
				throw new Error("YouTube.GetUploadTokenAction pending");
			}
		}
		
		private function onGetUploadTokenError(err:Event):void
		{
			// TODO: Dispatch Event
			//trace("YouTubeService::onGetUploadTokenError");
			cleanup();
		}
		
		private function onGetUploadTokenSuccess(evt:Event):void
		{
			var token:String = _getUploadTokenAction.token;
			var url:String = _getUploadTokenAction.uploadUrl;
			
			cleanup();
			
			_uploadAction = new UploadAction();
			_uploadAction.file = currentlyUploadingFile.file;
			_uploadAction.uploadToken = token;
			_uploadAction.url = url;
			_uploadAction.addEventListener(RestAction.REST_EVENT_ERROR,onUploadError);
			_uploadAction.addEventListener(RestAction.REST_EVENT_SUCCESS,onUploadSuccess);
			_uploadAction.addEventListener(UploadAction.REST_EVENT_PROGRESS,onUploadProgress);
			_uploadAction.execute();
			
			uploadFileIndex++;
		}
		
		private function onUploadError(evt:Event):void
		{
			// add to failed list
			cleanup();
			dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_UPLOAD_ERROR));
			dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_UPLOAD_COMPLETE));
		}
		
		private function onUploadSuccess(evt:Event):void
		{
			var id:String = _uploadAction.videoId;
			cleanup();
			if(this.isUploading && uploadQueue.length > 0)
			{
				uploadNextVideo();
			}
			else
			{
				this.isUploading = false;
				dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_UPLOAD_SUCCESS));
				dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_UPLOAD_COMPLETE));
				refreshUserVideos();
			}
		}
		
		public function stopUploading():void
		{
			if(this.isUploading)
			{
				if(_uploadAction != null)
				{
					_uploadAction.bytesLoaded
				}
			}
		}
		
		private function onUploadProgress(evt:Event):void
		{
			var bytesLoaded:int = _uploadAction.bytesLoaded;
			var bytesTotal:int = _uploadAction.bytesTotal;
			
			var progEvt:YouTubeEvent = new YouTubeEvent(YouTubeEvent.YTEVENT_UPLOAD_PROGRESS);
				progEvt.data = {bytesLoaded:bytesLoaded,bytesTotal:bytesTotal};
				
			dispatchEvent(progEvt);
		}
		
		public function storeUserCredentials():void
		{
			var so:SharedObject = SharedObject.getLocal(localSharedObjKey);
				so.data.username = tempCredentials.username;
				so.data.password = tempCredentials.password;
				so.flush();
		}
		
		public function clearUserCredentials():void
		{
			var so:SharedObject = SharedObject.getLocal(localSharedObjKey);
				so.data.username = null;
				so.data.password = null;
				so.flush();
		}
		
		public function get storedUsername():String
		{
			var so:SharedObject = SharedObject.getLocal(localSharedObjKey);
			if(so.data.username != null)
			{
				return so.data.username;
			}
			return "";
		}
		
		public function get storedPassword():String
		{
			var so:SharedObject = SharedObject.getLocal(localSharedObjKey);
			if(so.data.password != null)
			{
				return so.data.password;
			}
			return "";
		}
		
		

		private function checkCredentials():Boolean
		{
			if(this._clientID == null 	|| this._clientID.length <= 0 	||
			   this._devKey == null 	|| this._devKey.length <= 0)
		   {
		   		// dispatch error no credentials event
		   		dispatchEvent(new YouTubeEvent(YouTubeEvent.YTEVENT_NO_CREDENTIALS));
		   		return false;
		   }
		   return true;
		}
		
		private function cleanup():void
		{
			if(_loginAction != null)
			{
				_loginAction.removeEventListener(RestAction.REST_EVENT_ERROR,onLoginError);
				_loginAction.removeEventListener(RestAction.REST_EVENT_SUCCESS,onLoginSuccess);
				_loginAction = null;
			}
			if(_logoutAction != null)
			{
				_logoutAction.removeEventListener(RestAction.REST_EVENT_ERROR,onLogoutError);
				_logoutAction.removeEventListener(RestAction.REST_EVENT_SUCCESS,onLogoutSuccess);
			}
			if(_uploadAction != null)
			{
				_uploadAction.removeEventListener(RestAction.REST_EVENT_ERROR,onUploadError);
				_uploadAction.removeEventListener(RestAction.REST_EVENT_SUCCESS,onUploadSuccess);
				_uploadAction.removeEventListener(UploadAction.REST_EVENT_PROGRESS,onUploadProgress);
				_uploadAction = null;
			}
			if(_getUserVideosAction != null)
			{
				_getUserVideosAction.removeEventListener(RestAction.REST_EVENT_ERROR,onGetUserVideosError);
				_getUserVideosAction.removeEventListener(RestAction.REST_EVENT_SUCCESS,onGetUserVideosSuccess);
				_getUserVideosAction = null;
			}
			if(_getUploadTokenAction != null)
			{
				_getUploadTokenAction.removeEventListener(RestAction.REST_EVENT_ERROR,onRestError);
				_getUploadTokenAction.removeEventListener(RestAction.REST_EVENT_SUCCESS,onGetUploadTokenSuccess);
				_getUploadTokenAction = null;
			}
		}
		
		// Refresh Timer
		
		private function startRefreshTimer():void
		{
			if(_refreshTimer == null)
			{
				_refreshTimer = new Timer(TIMER_INTERVAL);
				_refreshTimer.addEventListener(TimerEvent.TIMER,onRefreshTimer);
			}
			_refreshTimer.start();
		}
		
		private function stopRefreshTimer():void
		{
			if(_refreshTimer != null)
			{
				_refreshTimer.stop();
			}
		}
		
		private function onRefreshTimer(evt:TimerEvent):void
		{
			refreshUserVideos();
		}
		
		
		// Event Handlers
		private function onRestError(evt:Event):void
		{
			// trace("YouTubeService::onRestError::");
			// TODO: Dispatch Event
			cleanup();
		}
		
		
		
	}
	
	
}