/**
 *
 * Dart Image Tag model
 *
 * Images are structured in a hierarchical file structure consisting of
 * directories and images (and movies). A directory may contain other
 * directories and image-files. A image file is a stream of data.
 *
 * A image can be thumbed by the server for the small image list.
 *
 */
import 'ImageTagDataSource.dart';
import 'dart:html';

abstract class Item {
  get IsDirectory;

  get IsImage;

  get IsTag;
}

class Error {
  String text();
}

class Tag extends Item {
  get IsDirectory => false;

  get IsImage => false;

  get IsTag => true;

  int _id;
  String _tag;
  String _description;

  Tag(this._id, this._tag, this._description);

  get Id => _id;
  get TheTag => _tag;
  get Description => _description;
}

class Image extends Item {
  get IsDirectory => false;

  get IsImage => true;

  get IsTag => false;

  get Name => _fileName;

  String _fileName;
  Directory _parent;

  Image(this._parent, this._fileName) {

  }


  void Load(ImageElement elm) {
    elm.src = "";
  }

  String absolutePath() {
    if (_parent == null) {
      return "";
    }
    return _parent.absolutePath() + "/" + _fileName;

  }

}

class Directory extends Item {

  get IsDirectory => true;

  get IsImage => false;

  get IsTag => false;

  String _name;
  Directory _parent;
  List<Item> _items;

  Directory(this._parent, this._name) {
    this._items = new List<Item>();
  }

  get IsRoot => this._parent == null;

  List<Item> getItems() {
    return this._items;
  }

  void addItem(Item item) {
    this._items.add(item);
  }

  String absolutePath() {
    if (_parent == null) {
      return "";
    }
    return _parent.absolutePath() + "/" + _name;
  }

  void setParent(Directory dir) {
    if (this._parent == null) {
      _parent = dir;
    }
  }

  get Parent => this._parent;
  get Name => this._name;
}



class ImageTagModel {
  ImageTagDataSource _source;
  Directory current;

  ImageTagModel(this._source) {
    SourceResult sr = _source.getRoot();
    if (sr.Data == null) {
      print(sr.Error.Message);
    } else {
      current = _source.getRoot().Data;
    }
  }

  void LoadThumbImage(Image image, ImageElement element) {
    String thumbUrl = _source.GetThumbPath(image);
    print(thumbUrl);
    element.src = thumbUrl;
  }

  void LoadImage(Image image, ImageElement element) {
    String imageUrl = _source.GetImagePath(image);
    print(imageUrl);
    element.src = imageUrl;
  }

  Directory GetCurrent() {
    return current;
  }

  void enterDirectory(Directory subDirectory) {
    SourceResult<Directory> sr = _source.loadDirectory(subDirectory.absolutePath());
    if (sr.Data != null) {
      Directory nextDir = sr.Data;
      nextDir.setParent(current);
      current = nextDir;
    }

  }

  List<Tag> getListOfTags() {
    SourceResult<List<Tag>> sr = _source.getTags();
    if (sr.Data != null) {
      return sr.Data;
    }
    return new List<Tag>();
  }

  void leaveDirectory() {
    if (current.Parent != null) {
      current = current.Parent;
    }
  }

  List<Tag> getTagsForImage(Image image) {

    SourceResult<List<Tag>> sr = _source.getTagsForImage(image);

    if (sr.Data != null) {
      return sr.Data;
    }
    print(sr.Error.Message);

    return new List<Tag>();
  }


  void removeTag(Tag tag, Image image) {
    _source.remoteTagForImage("${tag.Id}",image);
  }

  void assignTag(String tagId, Image image) {

    _source.assignTagToImage(tagId,image);

  }


  void AddNewTag(String tag, String descroption) {
    _source.addNewTag(tag,descroption);
  }


  List<Image> getImagesForTags(List<Tag> tags) {
    if (tags == null) {
      return new List<Image>();
    }
    SourceResult<List<Image>> images = _source.GetImagesForTags(tags);
    if (images.Data != null) {
      return images.Data;
    }
    return new List<Image>();
  }
}


