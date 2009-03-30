package com.nitobi.webapis.youtube
{
	import flash.filesystem.File;
	
	[Bindable]
	public class UserUpload
	{
		public static const FILESIZE_BYTES:Array = ["Bytes","KB","MB","GB"];
		
		// file is currently uploading
		public static const STATUS_UPLOADING:String = "uploading";
		
		// file has been uploaded
		public static const STATUS_COMPLETED:String = "completed";
		
		// file upload failed
		public static const STATUS_ERROR:String = "error";
		
		// file is in the queue
		public static const STATUS_QUEUED:String = "ready";
		
		// file details are being edited
		public static const STATUS_PENDING:String = "pending";
		
		
		public var name:String;
		public var uid:String;
		public var file:File;
		public var fileName:String;
		public var keywords:String;
		public var description:String;
		public var category:String;
		
		private var _uploadProgress:Number;
		private var _bytesUploaded:int;
		
		
		
		
		public function UserUpload()
		{
		}
		
		public function get formattedSize():String
		{
			var tempSize:Number = this.file.size;
			var index:int = 0;
			for(;index < FILESIZE_BYTES.length; index++)
			{
				if(tempSize < 1024)
					break;
				else
				{
					tempSize /= 1024;
				}
			}
			return tempSize.toPrecision(3) + " " + FILESIZE_BYTES[index];
		}
		
		public static function create(filePath:String):UserUpload
		{
			var lfi:UserUpload = new UserUpload();
			var file:File = new File(filePath);
			lfi.name = file.name;
			lfi.uid	= file.url;
			lfi.fileName = file.name;
			lfi.file = file;
			return lfi;
		}

	}
}