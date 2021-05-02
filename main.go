package main

import (
	"encoding/json"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"strconv"
)

const (
	limit  = "1000"
	apiURL = "https://api-v2.soundcloud.com"
)

var ids = []string{"1ZblcwqkcM5jJpypOqMGosmsvOPj2yqW", "5MlCU9alf35yL0Ub7owwSlLVcGLgiFIB", "Jso9j707fOmQVz48JLun3FOSX7ir5SPH"}

func getRandomID() string {
	return ids[rand.Intn(len(ids))]
}

func getJson(path string, query map[string]string) []byte {
	values := url.Values{}

	for k, v := range query {
		values.Set(k, v)
	}
	values.Set("client_id", getRandomID())

	res, err := http.Get(path + "?" + values.Encode())
	if err != nil {
		log.Fatal(err)
	}

	data, err := io.ReadAll(res.Body)
	res.Body.Close()
	if err != nil {
		log.Fatal(err)
	}
	return data
}

type track struct {
	Title     string `json:"title"`
	PermaLink string `json:"permalink"`

	Media struct {
		Transcodings []struct {
			URL    string `json:"url"`
			Format struct {
				Protocol string `json:"protocol"`
			} `json:"format"`
		} `json:"transcodings"`
	} `json:"media"`
}

func getUserID(user string) int {
	var data struct {
		Collection []struct {
			PermaLink string `json:"permalink"`
			ID        int    `json:"id"`
		} `json:"collection"`
	}
	json.Unmarshal(getJson(apiURL+"/search/users", map[string]string{"q": user, "limit": "20"}), &data)

	id := -1
	for _, c := range data.Collection {
		if c.PermaLink == user {
			id = c.ID
		}
	}
	if id == -1 {
		log.Fatal("Couldn't find user")
	}
	return id
}

func getUserTracks(id int) []track {
	var data struct {
		Collection []track `json:"collection"`
	}

	json.Unmarshal(getJson(apiURL+"/users/"+strconv.Itoa(id)+"/tracks", map[string]string{"limit": limit}), &data)

	return data.Collection
}

func getTrackMP3(t track) string {
	var data struct {
		URL string `json:"url"`
	}
	stream := t.Media.Transcodings[1]
	if stream.Format.Protocol != "progressive" {
		log.Fatal("Format is not correct")
	}
	json.Unmarshal(getJson(stream.URL, map[string]string{"limit": limit}), &data)
	return data.URL
}

func main() {
	archive := os.Args[1]
	user := os.Args[2]

	tracks := getUserTracks(getUserID(user))
	for _, track := range tracks[0:2] {
		resp, err := http.Get(getTrackMP3(track))
		if err != nil {
			log.Fatal("Couldn't request audio url")
		}
		defer resp.Body.Close()

		path := archive + "/" + user
		os.MkdirAll(path, os.ModePerm)
		out, err := os.Create(path + "/" + track.PermaLink + ".mp3")

		if err != nil {
			log.Fatal("Couldn't create file")
		}
		defer out.Close()
		io.Copy(out, resp.Body)
	}
}
