import 'dart:html';
import 'ImageTagModel.dart';
import 'ImageTagDataSource.dart';

class TagFilterController {

  SelectElement _tagSelect;
  ButtonElement _tagAdd;
  DivElement _tagFilterTags;
  ViewController _viewController;
  List<Tag> currentFilter;
  List<Tag> _tags;

  get Tags => currentFilter;

  TagFilterController() {
    _tagSelect = querySelector("#tag-filter-select");
    _tagAdd = querySelector("#tag-filter-add");
    _tagFilterTags = querySelector("#tag-filter-tags");
    _tagAdd.onClick.listen((e) => this.addTagToFilter());
    currentFilter = new List<Tag>();

  }

  void setViewController(ViewController vc) {

    this._viewController = vc;

  }

  void display(List<Tag> tags) {
    _tagSelect.children.clear();
    this._tags = tags;
    tags.forEach( (tag) {
      OptionElement oe = new OptionElement();
      oe.value = tag.Id;
      oe.text = tag.TheTag;
      oe.onClick.listen( (oe) => this.removeTag(tag) );
      _tagSelect.children.add(oe);
    });
  }

  void updateTagList() {
    _tagFilterTags.children.clear();
    currentFilter.forEach( (t) {
      SpanElement se = new SpanElement();
      se.className = "";
      se.innerHtml = t.TheTag;
      se.onClick.listen( (e) => removeTag(t) );
      _tagFilterTags.children.add(se);
    });

  }

  void addTagToFilter() {
    currentFilter.add(_tags[_tagSelect.selectedIndex]);
    _viewController.updateGrid(currentFilter);
    updateTagList();
  }

  void removeTag(Tag tag) {
    currentFilter.remove(tag);
    _viewController.updateGrid(currentFilter);
    updateTagList();
  }

}

class ImageGridController {

  DivElement _grid;
  ImageTagModel _model;
  ViewController _viewController;
  DivElement _large;

  ImageGridController(this._model) {
    _grid = querySelector("#image-grid");
    _large = querySelector("#large-display");
  }

  void setViewController(ViewController vc) {
    this._viewController = vc;
  }

  void display(List<Image> images) {
    _grid.children.clear();
    images.forEach( (image) {
      ImageElement img = new ImageElement();
      img.style.width = "200px";
      img.style.margin = "5px";
      _model.LoadThumbImage(image,img);
      _grid.children.add(img);
      img.onClick.listen( (e) => displayLarge(image));
    });
  }


  void displayLarge(Image image) {
    _large.children.clear();
    ImageElement img = new ImageElement();
    _model.LoadImage(image,img);
    _large.children.add(img);
    _large.style.display = 'block';
    _large.style.top = "${window.pageYOffset}px";
    img.style.width = "${window.innerWidth-100}px";
    _large.onClick.listen( (e) => _large.style.display = 'none');
  }
}

class ViewController {
  TagFilterController _tagController;
  ImageGridController _imageGrid;
  ImageTagModel _model;

  ViewController(this._model,this._tagController,this._imageGrid) {
    _tagController.setViewController(this);
    _imageGrid.setViewController(this);
  }

  void updateGrid(List<Tag> tags) {
    List<Image> images = _model.getImagesForTags(tags);
    _imageGrid.display(images);
  }

  void display() {
    _tagController.display(_model.getListOfTags());
    _imageGrid.display(_model.getImagesForTags(_tagController.Tags));
  }

}

main() {
  print("Tag View Alive");
  ImageTagDataSource source = new ImageTagDataSource("imagetag");
  ImageTagModel model = new ImageTagModel(source);
  TagFilterController filter = new TagFilterController();
  ImageGridController grid = new ImageGridController(model);
  ViewController view = new ViewController(model,filter,grid);
  view.display();
}