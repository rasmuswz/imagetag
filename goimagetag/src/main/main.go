package main

import (
	"os"
	"imagetagserver"
	"log"
	"runtime"
)

func main() {

	if len(os.Args) < 3 {
		println("ImageTagServer <dartBuildWebPath> <imgRoot>\n");
		return;
	}


	runtime.GOMAXPROCS(16);

	server := imagetagserver.New(os.Args[1],os.Args[2]);

	for {
		msg := <-server.GetEvents();
		if msg == imagetagserver.SRV_MSG_DIED {
			return;
		}
		log.Println(msg);
	}
}