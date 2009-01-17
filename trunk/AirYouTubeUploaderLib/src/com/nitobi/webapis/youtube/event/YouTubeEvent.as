package com.nitobi.webapis.youtube.event
{
	import flash.events.Event;

	public class YouTubeEvent extends Event
	{
		
		public static const YTEVENT_LOGIN_ERROR:String = "yt_login_error";
		public static const YTEVENT_LOGIN_START:String = "yt_login_start";
		public static const YTEVENT_LOGIN_SUCCESS:String = "yt_login_success";
		public static const YTEVENT_GOT_USER_VIDEOS:String = "yt_gotuservids";
		public static const YTEVENT_NO_CREDENTIALS:String = "yt_missingcreds";
		public static const YTEVENT_UPLOAD_TOKEN_SUCCESS:String = "yt_uploadtoken_success";
		public static const YTEVENT_UPLOAD_TOKEN_ERROR:String = "yt_uploadtoken_error";
		public static const YTEVENT_UPLOAD_SUCCESS:String = "yt_upload_success";
		public static const YTEVENT_UPLOAD_ERROR:String = "yt_upload_error";
		public static const YTEVENT_UPLOAD_COMPLETE:String = "yt_upload_complete";
		public static const YTEVENT_UPLOAD_PROGRESS:String = "yt_upload_progress";
		
		public static const YTEVENT_PROCESSING_COUNT_CHANGE:String = "yt_proc_count_change";
		
		public static const YTEVENT_FILESIZE_EXCEEDED:String = "yt_toofuckingbig";

		public var data:*;
		
		public function YouTubeEvent(type:String, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
		}
		
		
		
	}
}