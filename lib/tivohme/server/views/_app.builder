xml.Item do

  xml.Details do
    xml.ContentType app.content_type
    xml.SourceFormat "x-container/folder"
    xml.Title app.title
    xml.Uuid app.uuid
  end

  if locals[:show_genres]
    xml.Genres do
      app.genres.each do |genre|
        xml.Genre genre
      end
    end
  end

  xml.Links do

    xml.Content do
      xml.ContentType app.content_type
      xml.Url app.url
    end

    xml.CustomIcon do
      xml.Url app.icon_url
    end

  end

end
