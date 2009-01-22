package com.nitobi.webapis.youtube
{
	import com.adobe.utils.DateUtil;
	
	[Bindable]
	public class UserVideo
	{
		
		public static const STATUS_PROCESSING:String = "processing";
		public static const STATUS_ACTIVE:String = "active";
		public static const STATUS_REJECTED:String = "rejected";
		
		public static const WATCH_BASE_URL:String = "http://www.youtube.com/watch?v=";
		
		public var id:String;
		public var thumbnails:Array;
		public var title:String;
		public var published:Date;
		public var updated:Date;
		public var status:String; // processing | active | rejected
		public var reason:String; // ie. Duplicate video
		
/* // this is an example of a portion of a failed file
  <app:control xmlns:app="http://purl.org/atom/app#">
    <app:draft>yes</app:draft>
    <yt:state name="rejected" reasonCode="duplicate" helpUrl="http://www.youtube.com/t/community_guidelines">Duplicate video</yt:state>
  </app:control>
*/
			
		public function UserVideo(xml:XML = null)
		{
			if(xml != null)
			{
				this.id = xml.*::id.toString();
				
				this.thumbnails = new Array();
				this.thumbnails[0] = xml.*::group.*::thumbnail[0].@url.toString();
				this.thumbnails[1] = xml.*::group.*::thumbnail[1].@url.toString();
				this.thumbnails[2] = xml.*::group.*::thumbnail[2].@url.toString();
				
				this.title = xml.*::title.toString();
				this.published = DateUtil.parseW3CDTF(xml.*::published.toString());
				this.updated = DateUtil.parseW3CDTF(xml.*::updated.toString());
				this.status = xml.*.*::state.@name.toString();
				
				this.reason = xml.*.*::state.toString();

				if(this.status == "")
				{
					this.status = "active";
				}
			}
		}
		
		public function get watchUrl():String
		{
			return WATCH_BASE_URL + id.substr(id.lastIndexOf("/") + 1);
		}

        
        // update sets all values except ID, which is unique
        public function update(value:UserVideo):void
        {
				this.title = value.title;
				this.published = value.published;
				this.updated = value.updated;
				this.status = value.status;
				this.reason = value.reason;

				if(this.status == "")
				{
					this.status = "active";
				}
        }
	}
}