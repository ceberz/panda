class Hash
  def to_simple_xml
    hash_to_xml_string(self)
  end

private

  def hash_to_xml_string(h)
    s = ""
    h.each do |k,v|
      s += "<#{k}>"
      if v.class == Hash
        s += hash_to_xml_string(v)
      elsif v.class == Array
        v.each {|i|  s += hash_to_xml_string(i) }
      else
        s += v.to_s
      end
      s += "</#{k}>"
    end
    return s
  end
end