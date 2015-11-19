//
//
// ImageTagServer
//
//
// Author: Rasmus Winther Zakarias
//
package imagetagserver
import (
	"os"
	"net/http"
	"io/ioutil"
	"strings"
	"bytes"
	"encoding/json"
	"path/filepath"
	"log"
	"github.com/disintegration/imaging"
	_ "github.com/go-sql-driver/mysql"
	"database/sql"
	"strconv"
	"errors"
	"encoding/base64"
)

const (
	LISTEN_ON = ":8080";

	SRV_MSG_DIED = "died"

	ACTION_PARAMETER = "action";
	PATH_PARAMETER = "path";

	LIST_DIR_ACTION = "listdir";
	GET_TAGS_ACTION = "gettags";
	ASSIGN_TAG_ACTION = "assigntag";
	GET_TAGS_FOR_IMAGE_ACTION = "tagsforimage";
	REMOVE_TAG_FOR_IMAGE_ACTION = "removetag";
	ADD_NEW_TAG_ACTION = "newtag";
	GET_IMG_WITH_TAGS_ACTION = "imgwithtags";

	ITEM_TYPE_DIR = "dir";
	ITEM_TYPE_IMG = "img";
);

type ImageTagServer struct {
	docRoot string;
	imgRoot string;
	events  chan string;
}

func (ths *ImageTagServer) GetEvents() chan string {
	return ths.events;
}

func (ths *ImageTagServer) checkRoot() bool {

	info, err := os.Stat(ths.docRoot);
	if err != nil { return false; }

	if info.IsDir() == false {
		return false;
	}

	return true;
}

func (ths *ImageTagServer) listen() {

	if (ths.checkRoot() == false) {
		ths.events <- "died";
	};


	mux := http.NewServeMux();
	mux.HandleFunc("/", ths.serveFileSystem);
	mux.HandleFunc("/imagetag", ths.serveApi);
	e := http.ListenAndServe(LISTEN_ON, mux);
	if e != nil {
		log.Println(e.Error());
		ths.events <- SRV_MSG_DIED;
	}
}


func (ths *ImageTagServer) serveFileSystem(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close();

	path := r.URL.Path;
	path = ths.docRoot + path;

	info, infoErr := os.Stat(path);
	if infoErr != nil {
		ths.events <- infoErr.Error();
		http.Error(w, infoErr.Error(), http.StatusInternalServerError);
		return;
	}

	if info.IsDir() == false {
		var extMap map[string]string = map[string]string{"html": "text/html", "css": "text/css", "dart": "application/dart"};
		data, dataErr := ioutil.ReadFile(path);
		if dataErr != nil {
			ths.events <- dataErr.Error();
			http.Error(w, dataErr.Error(), http.StatusInternalServerError);
			return;
		}

		var mimeType = "text/plain";
		if strings.Contains(path, ".") {
			var ext = path[strings.LastIndex(path, ".") + 1:len(path)];
			var v, ok = extMap[ext];
			if ok {
				mimeType = v;
			}
		}

		w.Header().Add("Content-Type", mimeType);


		ths.GetEvents() <- "Serving: " + path;
		w.Write(data);
		return; // success
	}

	ths.GetEvents() <- "Requested object is not a file";
	http.Error(w, "Requested object is not a file", http.StatusForbidden);

}

type Directory struct {
	Name     string;
	Children string;
}

type Tag struct {
	Id          int;
	Tag         string;
	Description string;
}

func (ths *ImageTagServer) get_db() *sql.DB {

	db, err := sql.Open("mysql", "root:JeeGmt17@tcp(127.0.0.1:3306)/ImageTag?charset=utf8");
	if err != nil {
		log.Println("Error accessing DataBase: " + err.Error());
		return nil;
	}

	return db;
}

func (ths *ImageTagServer) get_tags(w http.ResponseWriter, r *http.Request) {

	err := errors.New("");

	db := ths.get_db();
	if db == nil {
		return;
	}

	var tags []*Tag = make([]*Tag, 0);

	defer db.Close();

	rows, rowsErr := db.Query("SELECT * FROM Tags");
	if rowsErr != nil {
		http.Error(w, rowsErr.Error(), http.StatusInternalServerError);
		log.Println("Error access database: " + rowsErr.Error());
		return;
	}
	for rows.Next() {
		var t Tag = Tag{};
		err = rows.Scan(&t.Id, &t.Tag, &t.Description);
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError);
			log.Println(err.Error());
			return;
		}
		tags = append(tags, &t);
		print(t.Tag + "\n");
	}
	jStr, _ := json.Marshal(tags);
	print("JSON Tags: " + string(jStr) + "\n");

	w.Write(jStr);


}

func (ths *ImageTagServer) assign_tag(w http.ResponseWriter, r *http.Request) {

	db := ths.get_db();
	if db == nil {
		return;
	}
	defer db.Close();

	tagId := r.URL.Query().Get("tagId");
	imgPath := r.URL.Query().Get("imgPath");
	rows, rowsErr := db.Query("SELECT Id FROM Image WHERE Path LIKE '" + imgPath + "';");
	if rowsErr != nil {
		log.Println("Error from db: " + rowsErr.Error());
		http.Error(w, "DataBase failure", http.StatusInternalServerError);
		return;
	}

	imageId := "";
	var imgIdInt int64 = 0;
	ok := rows.Next();
	if ok == false {

		res, resErr := db.Exec("INSERT INTO Image(Path,Description) VALUES('" + imgPath + "','GoLang');");
		if resErr != nil {
			log.Println(resErr.Error());
			http.Error(w, resErr.Error(), http.StatusInternalServerError);
			return;
		}

		imgIdInt, rowsErr = res.LastInsertId();
		imageId = strconv.FormatInt(imgIdInt, 10);

		log.Println("Inserted Image into database:\nid:" + imageId + "\npath:" + imgPath + "\n");
	} else {
		rowsErr = rows.Scan(&imgIdInt);
		if rowsErr != nil {
			log.Println(rowsErr.Error());
			http.Error(w, "Could not extract Id from image row ?\n" + rowsErr.Error(), http.StatusInternalServerError);
			return;
		}
	}
	imageId = strconv.FormatInt(imgIdInt, 10);

	q := "INSERT INTO Assignment(TagId,ImageId) VALUES('" + tagId + "','" + imageId + "');";
	rows, rowsErr = db.Query(q);
	if rowsErr != nil {
		log.Println(rowsErr.Error());
		http.Error(w, "Could not register assignment in DB:\n" + rowsErr.Error(), http.StatusInternalServerError);
		return;
	}

	log.Println("TagId: " + tagId + " successfully assigned to image: " + imageId);

}

func (ths *ImageTagServer) go_list_dir(w http.ResponseWriter, r *http.Request) {
	var exts map[string]bool = map[string]bool{".jpg": true, ".png": true, ".JPG": true};

	path := r.URL.Query().Get("path");
	path = ths.imgRoot + path;
	path = strings.Replace(path, "..", "", -1);

	println("Path: " + path)

	info, infoErr := os.Stat(path);
	if infoErr != nil {
		ths.GetEvents() <- "Path err: " + infoErr.Error();
		http.Error(w, infoErr.Error(), http.StatusNotFound);
		return;
	}

	if info.IsDir() == false {
		ths.GetEvents() <- path + " - no such directory";
		http.Error(w, "No such directory", http.StatusNotFound);
		return;
	}

	result := new(Directory);
	result.Name = info.Name();

	children := bytes.NewBuffer(nil);

	files, _ := ioutil.ReadDir(path);
	for file := range files {
		finfo, finfoErr := os.Stat(path + "/" + files[file].Name());
		if finfoErr != nil {
			ths.GetEvents() <- finfoErr.Error();
			continue;
		}

		if finfo.IsDir() == true {
			fname := filepath.Base(files[file].Name());
			children.WriteString(fname + "|" + ITEM_TYPE_DIR + ";");
		} else {
			ths.events <- ("Extension is: " + filepath.Ext(path + finfo.Name()));
			if _, ok := exts[filepath.Ext(path + finfo.Name())]; ok {
				fname := filepath.Base(files[file].Name());
				children.WriteString(fname + "|" + ITEM_TYPE_IMG + ";");
			}
		}
	}

	result.Children = children.String();
	println(result.Children);
	jsonStr, jsonStrErr := json.Marshal(result);
	if jsonStrErr != nil {
		ths.GetEvents() <- jsonStrErr.Error();
	}

	println(string(jsonStr));
	w.Write(jsonStr);
	return;

}

func (ths *ImageTagServer) go_thumb_image(w http.ResponseWriter, r *http.Request) {
	imgPath := r.URL.Query().Get("path");
	path := imgPath;
	path = ths.imgRoot + path;
	path = strings.Replace(path, "..", "", -1);

	info, infoErr := os.Stat(path);
	if infoErr != nil {
		http.Error(w, infoErr.Error(), http.StatusInternalServerError);
		return;
	}

	db := ths.get_db();
	if db == nil {
		return;
	}
	defer db.Close();

	row,rerr := db.Query("SELECT Thumb FROM Image WHERE Path LIKE '"+imgPath+"';");
	if rerr != nil {
		log.Println(rerr.Error());
		http.Error(w,rerr.Error(),http.StatusInternalServerError);
		return;
	}

	if row.Next() {
		var result string;
		e := row.Scan(&result);
		if e != nil {
			log.Println(e.Error());
			http.Error(w,e.Error(),http.StatusInternalServerError);
			return;
		}
		b,_ := base64.StdEncoding.DecodeString(result);

		w.Header().Add("Content-Type", "image/jpeg");
		w.Write(b);
		return;
	}


	if info.IsDir() == true {
		http.Error(w, "No an image", http.StatusBadRequest);
		return;
	}

	img, err := imaging.Open(path);
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError);
		return;
	}

	thumb := imaging.Thumbnail(img, 300, 300, imaging.CatmullRom);

	buffer := bytes.NewBuffer(nil);
	imaging.Encode(buffer,thumb,imaging.JPEG);
	b64 := base64.StdEncoding.EncodeToString(buffer.Bytes());

	insertRes,insertResErr := db.Exec("INSERT INTO Image(Path,Thumb) VALUES('"+imgPath+"','"+b64+"');");
	if insertResErr != nil {
		log.Println(insertResErr.Error());
		http.Error(w,insertResErr.Error(),http.StatusInternalServerError);
		return;
	}
	iid,_ := insertRes.LastInsertId();
	log.Println("Added image \""+imgPath+"\" with id "+strconv.FormatInt(iid,10));

	w.Header().Add("Content-Type", "image/jpeg");
	w.Write(buffer.Bytes());
	if err != nil {
		http.Error(w, "Failed to thumbNail image", http.StatusInternalServerError);
		return;
	}

}

func (ths *ImageTagServer) go_get_image(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path");
	path = ths.imgRoot + path;
	path = strings.Replace(path, "..", "", -1);

	info, infoErr := os.Stat(path);
	if infoErr != nil {
		http.Error(w, infoErr.Error(), http.StatusInternalServerError);
		return;
	}

	if info.IsDir() == true {
		http.Error(w, "No an image", http.StatusBadRequest);
		return;
	}

	img, err := imaging.Open(path);
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError);
		return;
	}

	w.Header().Add("Content-Type", "image/jpeg");
	err = imaging.Encode(w, img, imaging.JPEG);
	if err != nil {
		http.Error(w, "Failed to thumbNail image", http.StatusInternalServerError);
		return;
	}


}

func (ths *ImageTagServer) remove_tag_for_iamge(w http.ResponseWriter, r *http.Request) {
	imgPath := r.URL.Query().Get("imgPath");
	tagId := r.URL.Query().Get("tagId");

	db := ths.get_db();
	if db == nil {
		http.Error(w, "DataBase error.", http.StatusInternalServerError);
		return;
	}
	defer db.Close();

	imgIdQ := "SELECT Id FROM Image WHERE Path LIKE '" + imgPath + "'";

	res,resErr := db.Exec("DELETE FROM Assignment WHERE TagId LIKE '"+tagId+"' AND ImageId IN ("+imgIdQ+")");

	if resErr != nil {
		log.Println("DataBase Error: " + resErr.Error());
		http.Error(w, "DataBase Error.:" + resErr.Error(), http.StatusInternalServerError);
		return;
	}

	count,countErr := res.RowsAffected();

	if countErr != nil {
		log.Println(countErr.Error());
		http.Error(w,countErr.Error(),http.StatusInternalServerError);
		return;
	}

	if count < 1 {
		log.Println("No rows affected by query");
		http.Error(w,"No such tag registered.",http.StatusBadRequest);
		return;
	}

	log.Println(" Tag with Id "+tagId+" successfully removed from image "+imgPath);
}

func (ths *ImageTagServer) get_tags_for_image(w http.ResponseWriter, r *http.Request) {
	imgPath := r.URL.Query().Get("imgPath");

	db := ths.get_db();
	if db == nil {
		http.Error(w, "DataBase error.", http.StatusInternalServerError);
		return;
	}
	defer db.Close();

	q := "SELECT Id,Tag,Description FROM Tags " +
	     "WHERE Id IN (SELECT TagId FROM Assignment WHERE ImageId IN (SELECT Id FROM Image WHERE Path LIKE '"+imgPath+"'));"
	res, resErr := db.Query(q);
	if resErr != nil {
		log.Println("DataBase Error: " + resErr.Error());
		http.Error(w, "DataBase Error.:" + resErr.Error(), http.StatusInternalServerError);
		return;
	}

	var tags []*Tag = make([]*Tag,0);
	for res.Next() {
		var t Tag = Tag{};
		err := res.Scan(&t.Id, &t.Tag, &t.Description);
		if err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError);
			log.Println(err.Error());
			return;
		}
		tags = append(tags, &t);
		print(t.Tag + "\n");
	}

	jStr, _ := json.Marshal(tags);
	print("JSON Tags: " + string(jStr) + "\n");

	w.Write(jStr);
	log.Println("Successfully sent tags for image: "+imgPath);
}


func (ths *ImageTagServer) get_images_with_tags(w http.ResponseWriter, r *http.Request){

	tagData,tagDataErr := ioutil.ReadAll(r.Body);
	if tagDataErr != nil {
		log.Println(tagDataErr.Error());
		http.Error(w,tagDataErr.Error(),http.StatusInternalServerError);
		return;
	}

	log.Println(string(tagData));

	var tags []string = make([]string,0);
	jErr := json.Unmarshal(tagData,&tags);
	if jErr != nil {
		log.Println(jErr.Error());
		http.Error(w,jErr.Error(),http.StatusInternalServerError);
		return;
	}

	db := ths.get_db();
	if db == nil {
		http.Error(w, "DataBase error.", http.StatusInternalServerError);
		return;
	}
	defer db.Close();

	var imgPaths []string = make([]string,0);
	q := "SELECT Id,Path FROM Image WHERE Id IN (SELECT ImageId FROM Assignment WHERE TagId = ";
	for i := 0; i < len(tags); i++ {
		rows,rowsErr := db.Query(q+"'"+tags[i]+"');");

		if rowsErr != nil {
			log.Println(rowsErr.Error());
			http.Error(w,rowsErr.Error(),http.StatusInternalServerError);
			return;
		}


		for rows.Next() {
			var id int = 0;
			var path string = "";

			err:=rows.Scan(&id,&path);
			if err != nil {
				log.Println(err.Error());
				http.Error(w,"Error: "+err.Error(),http.StatusInternalServerError);
				return;
			}
			imgPaths = append(imgPaths,path);
		}
	}
	rb,rbe := json.Marshal(imgPaths);
	if rbe != nil {
		log.Println(rbe.Error());
		http.Error(w,rbe.Error(),http.StatusInternalServerError);
		return;
	}
	w.Write(rb);
	log.Println("Listing images for tags successful.");
}

func (ths *ImageTagServer) add_tag(w http.ResponseWriter, r *http.Request) {

	tag := r.URL.Query().Get("tag");
	desc:= r.URL.Query().Get("description");

	db := ths.get_db();
	if db == nil {
		http.Error(w, "DataBase error.", http.StatusInternalServerError);
		return;
	}
	defer db.Close();

	res,resErr := db.Exec("INSERT INTO Tags(Tag,Description) VALUES('"+tag+"','"+desc+"');");
	if resErr != nil {
		log.Println(resErr.Error());
		http.Error(w,resErr.Error(),http.StatusInternalServerError);
		return;
	}

	c,_ := res.RowsAffected() ;
	if c < 1 {
		log.Println("No tag added");
		http.Error(w,"No tag added",http.StatusInternalServerError);
		return;
	}

	log.Println("Tag: "+tag+" added with success.");
}

const GET_IMAGE_ACTION = "getimage";

const GET_THUMB_IMAGE_ACTION = "getthumb";

func (ths *ImageTagServer) serveApi(w http.ResponseWriter, r *http.Request) {
	defer r.Body.Close();

	log.Println("Servicing APi");

	action := r.URL.Query().Get(ACTION_PARAMETER);

	if strings.Compare(action, LIST_DIR_ACTION) == 0 {
		ths.go_list_dir(w, r);
		return;
	}

	if (strings.Compare(action, GET_THUMB_IMAGE_ACTION) == 0) {
		ths.go_thumb_image(w, r);
		return;
	}

	if (strings.Compare(action, GET_IMAGE_ACTION) == 0) {
		ths.go_get_image(w, r);
		return;
	}

	if (strings.Compare(action, GET_TAGS_ACTION) == 0) {
		ths.get_tags(w, r);
		return;
	}

	if (strings.Compare(action, ASSIGN_TAG_ACTION) == 0) {
		ths.assign_tag(w, r);
		return;
	}

	if (strings.Compare(action, GET_TAGS_FOR_IMAGE_ACTION) == 0) {
		ths.get_tags_for_image(w, r);
		return;
	}

	if (strings.Compare(action,REMOVE_TAG_FOR_IMAGE_ACTION) == 0) {
		ths.remove_tag_for_iamge(w, r);
		return;
	}

	if (strings.Compare(action,ADD_NEW_TAG_ACTION) == 0) {
		ths.add_tag(w,r);
		return;
	}

	if (strings.Compare(action, GET_IMG_WITH_TAGS_ACTION) == 0) {
		ths.get_images_with_tags(w,r);
		return;
	}


	http.Error(w, "Unsupported action " + action, http.StatusBadRequest);
}


func New(docRoot string, imgRoot string) *ImageTagServer {
	result := new(ImageTagServer);
	result.docRoot = docRoot;
	result.imgRoot = imgRoot;
	result.events = make(chan string);
	go result.listen();
	return result;
}