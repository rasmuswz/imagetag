/**
 *
 * ImageTag 4 - Main Controller
 *
 * +------------------------------------------------+
 * |                                                |
 * | +- tag --+    +-----------------------------+  |
 * |               |                             |  |
 * |               |          MainImage          |  |
 * |               |                             |  |
 * |               |                             |  |
 * |               +-----------------------------+  |
 * |                                                |
 * | +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+   |
 * | |  | |  | |  | |  | |  | |  | |  | |  | |  |   |
 * | +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+   |
 * |                                                |
 * | +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+   |
 * | |  | |  | |  | |  | |  | |  | |  | |  | |  |   |
 * | +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+ +--+   |
 * |                                                |
 * +------------------------------------------------+
 *
 *
 */

import 'ImageTagDataSource.dart';
import 'ImageTagModel.dart';
import 'dart:html';
import 'dart:async';

class MainImageViewController {

  ImageElement _view;
  ImageElement _load;
  ViewController _viewController;
  SpanElement _leaveButton;
  ButtonElement _next;
  ButtonElement _prev;

  MainImageViewController() {
    _view = querySelector("#main-image-view");
    _load = querySelector("#main-image-loading-view");
    _leaveButton = querySelector("#leave-dir");

    _leaveButton.onClick.listen ( (e) {
      _viewController.leaveDirectory();
    });

    _next = querySelector("#main-image-view-next");
    _prev = querySelector("#main-image-view-prev");

    _next.onClick.listen ((e) {
        _viewController.nextWindow();
    });

    _prev.onClick.listen( (e) {
        _viewController.prevWindow();
    });
  }

  void setViewController(ViewController vc) {
    this._viewController = vc;
  }
  void setImage(Image image) {
    _view.style.display = 'none';
    _load.style.display = 'block';
    _view.onLoad.listen((e) => this.swapLoadingForImage());

    _viewController.LoadImage(image,_view);
  }

  void swapLoadingForImage() {
    _view.style.display = 'block';
    _load.style.display = 'none';
  }

}

class TagSelectController {

  SelectElement _view;
  ButtonElement _assignBtn;
  ViewController _viewController;
  ImageTagModel _model;
  Image selectedImage;
  ButtonElement _addTag;

  //
  DivElement _newTagDialog;
  InputElement _newTagTag;
  TextAreaElement _newTagDescription;
  ButtonElement _newTagDialogAdd;
  ButtonElement _newTagDialogCancel;

  int _selectedTagIndex;

  TagSelectController(this._model) {
    _view = querySelector("#tag-select");
    _assignBtn = querySelector("#assign-tag");
    _addTag = querySelector("#add-tag-btn");

    _newTagDialog = querySelector("#new-tag-dialog");
    _newTagTag = querySelector("#new-tag-tag");
    _newTagDescription = querySelector("#new-tag-description");
    _newTagDialogAdd = querySelector("#new-tag-add");
    _newTagDialogCancel = querySelector("#new-tag-cancel");

    _assignBtn.onClick.listen( (e) => this.AssignTagForImage());
    _addTag.onClick.listen((e) => this.AddTag());
    _newTagDialogAdd.onClick.listen( (e) => this.DoAddTag());
    _newTagDialogCancel.onClick.listen( (e) => this.CancelAddTag());

  }

  void updateTags() {
    _view.children.clear();
    List<Tag> tags = _model.getListOfTags();
    tags.forEach( (tag) {
        OptionElement tagOption = new OptionElement();
        tagOption.innerHtml = "${tag.TheTag}";
        tagOption.value = tag.Id;
        _view.children.add(tagOption);
        print("adding tag ${tag.TheTag}");
    });
    if (tags.length > this._selectedTagIndex) {
      _view.selectedIndex = this._selectedTagIndex;
    } else {
      this._selectedTagIndex = 0;
    }
  }

  void setViewController(ViewController viewController) {
    this._viewController = viewController;
  }

  void hide(){
    _view.style.display = 'none';
  }

  void display() {
    _view.style.display = 'block';
  }

  void ImageSelected(Image image) {
    this.selectedImage = image;
  }

  void AssignTagForImage() {
    if (selectedImage != null) {
      String tagId = _view.options[_view.selectedIndex].value;
      _model.assignTag(tagId,selectedImage);
      this._selectedTagIndex = _view.selectedIndex;
      _viewController.RefreshSideBar(selectedImage);
    }
  }

  void AddTag() {
    _newTagDialog.style.display = 'block';
  }

  void clearAddTagDialog() {
    _newTagTag.value = "";
    _newTagDescription.value = "";
    _newTagDialog.style.display = 'none';
  }

  void DoAddTag() {
    String tagTag = _newTagTag.value;
    String tagDesc= _newTagDescription.value;
    _model.AddNewTag(tagTag,tagDesc);
    clearAddTagDialog();
    updateTags();
  }

  void CancelAddTag() {
    clearAddTagDialog();
  }

}

class AssignedTagListController {

  UListElement _view;
  ImageTagModel _model;

  AssignedTagListController(this._model) {
    _view = querySelector("#tag-list");
  }

  void display(Image image) {
    print("Running dosplay on assigned tag list");
    _view.children.clear();
    List<Tag> tagsForImage = _model.getTagsForImage(image);
    tagsForImage.forEach( (tag) {
      LIElement tagElm = new LIElement();
      tagElm.innerHtml = "${tag.TheTag}";
      tagElm.className = "list-group-item";
      SpanElement delete = new SpanElement();
      delete.className = "glyphicon glyphicon-remove";
      tagElm.children.add(delete);
      delete.onClick.listen( (e) => this.removeTag(tag,image));
      _view.children.add(tagElm);
    });
  }

  void removeTag(Tag tag, Image image) {
    _model.removeTag(tag,image);
    display(image);
  }

}

class ImageThumbItemViewController {

  ImageElement _image;
  ImageElement _load;
  StreamSubscription<Event> _imageOnClick;

  Element _text;
  ViewController _viewController;


  ImageThumbItemViewController(this._viewController, int i, int j) {

    if (j == 10) {
      _image = querySelector("#img${i}A");
      _load = querySelector("#ldr${i}A");
      _text = querySelector("#img${i}Atext");
    } else {
      _image = querySelector("#img${i}${j}");
      _load = querySelector("#ldr${i}${j}");
      _text = querySelector("#img${i}${j}text");
    }
    _image.onLoad.listen((e) {
      _image.style.display = 'block';
      _text.style.display = 'block';
      _load.style.display = 'none';
    });
  }

  void loading() {
    _image.style.display = 'none';
    _text.style.display='none';
    _load.style.display = 'block';

  }

  void hide() {
    _image.style.display = 'none';
    _text.style.display = 'none';
    _load.style.display = 'none';
  }

  void setItem(Item item) {
    loading();

    if (item.IsDirectory) {
      Directory dir = item;
      _image.src = "images/imagefolder.png";
      _text.innerHtml = dir.Name;
      if (this._imageOnClick != null) {
        this._imageOnClick.cancel();
      }
      this._imageOnClick = _image.onClick.listen( (e) {
        _viewController.EnterDirectory(dir);
      });
    }

    if (item.IsImage) {
      Image image = item;
      _viewController.LoadThumbImage(image,_image);
      _text.innerHtml = image.Name;
      if (this._imageOnClick != null) {
        this._imageOnClick.cancel();
      }
      this._imageOnClick = _image.onClick.listen((e) {
        _viewController.ImageSelected(image);
      });
    }
  }


}

class SlidingImageWindowController {

  List<ImageThumbItemViewController> _views;
  ViewController _viewController;
  Element _path;


  SlidingImageWindowController() {
    _path = querySelector("#path-so-far");
  }

  void initialize() {
    _views = new List<ImageThumbItemViewController>();
    print("Just created _views: ${_views}");
    for (int j = 1; j < 3; ++j) {
      for (int i = 1; i < 11; ++i) {
        _views.add(new ImageThumbItemViewController(_viewController, j, i));
      }
    }
  }

  void setViewController(ViewController viewController) {
    this._viewController = viewController;
    initialize();
  }

  void display(List<Item> items, int offset) {
    for (int i = 0; i < this._views.length;++i) {
      int idx = i + offset;
      ImageThumbItemViewController view = _views[i];
      if (idx < items.length) {
        Item current = items[idx];
        view.setItem(current);
      } else {
        view.hide();
      }
    }
  }

  void ImageSelected(Image image) {
    this._path.innerHtml = image.absolutePath();
  }

  void DirectorySelected(Directory dir) {
    this._path.innerHtml = dir.absolutePath();
  }
}

class ViewController {
  MainImageViewController _mainImage;
  InfoSideBarController _sideBar;
  SlidingImageWindowController _window;
  ImageTagModel _model;
  int _offset;

  ViewController(this._mainImage, this._sideBar, this._window, this._model) {
    _window.setViewController(this);
    _mainImage.setViewController(this);
    _sideBar.setViewController(this);
    _offset = 0;
  }

  void display() {
    Directory dir = _model.GetCurrent();
    _window.display(dir.getItems(),_offset);
    _sideBar.display();
  }

  void RefreshSideBar(Image image){
    _sideBar.ImageSelected(image);
  }

  void ImageSelected(Image image) {
    _mainImage.setImage(image);
    _sideBar.ImageSelected(image);
    _window.ImageSelected(image);
  }

  void EnterDirectory(Directory dir) {
    _model.enterDirectory(dir);
    _window.DirectorySelected(_model.current);
    _offset = 0;
    display();
  }

  void LoadThumbImage(Image img, ImageElement elm) {
    _model.LoadThumbImage(img,elm);
  }

  void LoadImage(Image img, ImageElement elm) {
    _model.LoadImage(img,elm);
  }

  void leaveDirectory() {
    _model.leaveDirectory();
    _offset = 0;
    _window.DirectorySelected(_model.current);
    display();

  }

  void nextWindow() {
    this._offset += 10;
    display();
  }

  void prevWindow() {
    if (this._offset > 10) {
      this._offset -= 10;
    }
    display();
  }
}

class InfoSideBarController {

  TagSelectController _tagSelector;
  AssignedTagListController _tagList;
  Element _imageName;

  ViewController _viewController;
  ImageTagModel _model;

  InfoSideBarController(this._model) {
    _tagSelector = new TagSelectController(_model);
    _tagList = new AssignedTagListController(_model);
    _imageName = querySelector("#sidebar-image-name");
  }

  void setViewController(ViewController viewController) {
    this._viewController = _viewController;
    this._tagSelector.setViewController(viewController);
  }

  void ImageSelected(Image image) {
    _tagSelector.updateTags();
    _tagSelector.display();
    _tagSelector.ImageSelected(image);
    _tagList.display(image);
    _imageName.innerHtml = image.Name;
  }

  void display() {

  }
}

void main() {
  print("Dart alive");
  ImageTagDataSource source = new ImageTagDataSource("imagetag");
  ImageTagModel model = new ImageTagModel(source);
  MainImageViewController mainImage = new MainImageViewController();
  InfoSideBarController sideBar = new InfoSideBarController(model);
  SlidingImageWindowController window = new SlidingImageWindowController();
  ViewController view = new ViewController(mainImage, sideBar, window, model);
  view.display();
}

