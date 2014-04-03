xml.instruct! :xml, :version => '1.0'
xml.TiVoContainer do
  xml << yield
end
