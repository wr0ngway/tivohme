xml.Details do
  xml.ContentType "x-container/tivo-server"
  xml.SourceFormat "x-container/folder"
  xml.TotalItems apps.size
  xml.Title "HME Server for Ruby"
end
xml.ItemStart 0
xml.ItemCount apps.size
apps.each do |app|
  builder :_app, :layout => false, :locals => { :xml => xml, :app => app }
end
