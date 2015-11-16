/**
 *
 * Image tag data source implements a protocol with the Image Tag server
 * to retrieve images.
 */
import 'ImageTagModel.dart';
import 'dart:html';
import 'dart:convert';

// --------------- ACTIONS ---------------
const String ACTION_LIST_DIR = "listdir";
const String ACTION_THUMB_IMAGE = "getthumb";
const String ACTION_IMAGE = "getimage";
const String ACTION_GET_TAGS = "gettags";
const String ACTION_ASSIGN_TAG = "assigntag";
const String ACTION_GET_TAGS_FOR_IMAGE = "tagsforimage";
const String ACTION_REMOVE_TAG = "removetag";
const String ACTION_ADD_NEW_TAG = "newtag";
const String ACTION_GET_IMAGES_WITH_TAGS = "imgwithtags";

// --------------- TYPES   ---------------
const String TYPE_DIR = "dir";
const String TYPE_IMG = "img";

const ITEM_ENTRY_NAME_KEY = "Name";
const ITEM_CHILDREN_KEY = "Children";

class QueryResponse {

  String _text;
  bool _OK;

  QueryResponse.OK(this._text) {
    this._OK = true;
  }

  QueryResponse.Fail(this._text) {
    this._OK = false;
  }

  get Text => this._text;

  get IsOk => this._OK;
}


class SourceError {
  String _message;

  SourceError(this._message);

  get Message => _message;
}

class SourceResult<T> {

  SourceError _error;
  T _result;

  SourceResult.Ok(this._result);

  SourceResult.Err(this._error);

  get Error => _error;

  get Data => _result;
}

class ImageTagDataSource {

  String _apiPoint;


  ImageTagDataSource(this._apiPoint) {

  }

  QueryResponse _queryServer(String action, String data, Map<String, String> params) {
    const int STATUS_OK = 200;
    HttpRequest request = new HttpRequest();
    String q = _apiPoint + "?action=" + action;
    if (params != null) {
      params.forEach((k, v) {
        q += "&${k}=${v}";
      });
    }
    request.open(data == null ? "GET" : "POST", q, async: false);
    request.send(data);

    if (request.status == STATUS_OK) {
      return new QueryResponse.OK(request.responseText);
    } else {
      return new QueryResponse.Fail(request.statusText);
    }
  }

  SourceResult<Directory> getDirectory(String path) {
    print("The we ask for: ${path}");
    QueryResponse response = _queryServer(ACTION_LIST_DIR, null, {"path": path});

    if (response.IsOk) {
      var data = JSON.decode(response.Text);

      if (data == null) {
        print("Failed to decode JSON.");
      }

      print("${data}");

      Directory result = new Directory(null, data[ITEM_ENTRY_NAME_KEY]);

      List<String> items = data[ITEM_CHILDREN_KEY].split(";");
      items.forEach((itm) {
        if (itm.contains("|")) {
          List<String> nameAndType = itm.split("|");
          if (nameAndType.length == 2) {
            if (nameAndType[1] == TYPE_DIR) {
              result.addItem(new Directory(result, nameAndType[0]));
            }

            if (nameAndType[1] == TYPE_IMG) {
              result.addItem(new Image(result, nameAndType[0]));
            }
          }
        }
      });
      return new SourceResult.Ok(result);
    }
    return new SourceResult.Err(new SourceError(response.Text));
  }

  SourceResult<Directory> getRoot() {
    return this.getDirectory("");
  }

  SourceResult<Directory> loadDirectory(String absolutePath) {
    print(absolutePath);
    return this.getDirectory(absolutePath);
  }

  String GetThumbPath(Image image) {
    var q = _apiPoint + "?action=" + ACTION_THUMB_IMAGE + "&path=" + image.absolutePath();
    return q;
  }

  String GetImagePath(Image image) {
    var q = _apiPoint + "?action=" + ACTION_IMAGE + "&path=" + image.absolutePath();
    return q;
  }


  SourceResult<List<Tag>> getTags() {

    QueryResponse response = _queryServer(ACTION_GET_TAGS, null, {});
    if (response.IsOk) {
      List<Tag> tags = new List<Tag>();
      List result = JSON.decode(response.Text);
      result.forEach( (m) {
        tags.add(new Tag(m["Id"],m["Tag"],m["Description"]));
      });
      return new SourceResult.Ok(tags);
    }
    return new SourceResult<List<Tag>>.Err(new SourceError(response.Text));
  }


  void assignTagToImage(String tagId, Image image) {
    QueryResponse r = _queryServer(ACTION_ASSIGN_TAG,null,{"tagId": tagId, "imgPath": image.absolutePath()});
    if (r.IsOk) {
      print("${tagId} successfullt assigned to ${image.absolutePath()}");
    } else {
      print(r.Text);
    }
  }


  SourceResult<List<Tag>> getTagsForImage(Image image) {
    QueryResponse r = _queryServer(ACTION_GET_TAGS_FOR_IMAGE,null,{"imgPath": image.absolutePath()});
    if (r.IsOk) {
      List result = JSON.decode(r.Text);
      List<Tag> tags = new List<Tag>();
      result.forEach( (m) {
        tags.add(new Tag(m["Id"],m["Tag"],m["Description"]));
      });
      return new SourceResult.Ok(tags);
    }
    return new  SourceResult.Err(new SourceError(r.Text));
  }

  void remoteTagForImage(String tagId, Image image) {
    QueryResponse r = _queryServer(ACTION_REMOVE_TAG,null,{"tagId": tagId, "imgPath": image.absolutePath()});
    if (r.IsOk == false ) {
      print(r.Text);
    }
  }

  void addNewTag(String tag, String description) {

    QueryResponse r = _queryServer(ACTION_ADD_NEW_TAG,null,{"tag": tag, "description": description});
    if (r.IsOk == false) {
      print(r.Text);
    }
  }

  SourceResult<List<Image>> GetImagesForTags(List<Tag> tags) {

    List<String> tagIds = new List<String>();
    tags.forEach( (t) => tagIds.add("${t.Id}"));

    String serTags = JSON.encode(tagIds);
    print("serialised tags ${serTags}");
    QueryResponse r = _queryServer(ACTION_GET_IMAGES_WITH_TAGS,serTags,null);
    if (r.IsOk) {
      List<Image> result = new List<Image>();
      List images = JSON.decode(r.Text);
      images.forEach((path) {
        List<String> pathElements = path.split("/");
        Directory d = null;
        pathElements.forEach((pe) {
          d = new Directory(d, pe);
        });
        Image image = new Image(d.Parent, pathElements[pathElements.length - 1]);
        result.add(image);
      });
      return new SourceResult.Ok(result);
    }
    return new SourceResult.Err(new SourceError(r.Text));
  }

}