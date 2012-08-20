#MONKEYPATCHTHATHASH!
class ::Hash
  def deep_merge(hash)
    
  end

  def deep_merge!(second)
    deep_safe_merge(self,second)
  end

  private
  def deep_safe_merge(source_hash, new_hash)
    source_hash.merge!(new_hash) do |key, old, new|
      if new.respond_to?(:blank) && new.blank?
          old
      elsif (old.kind_of?(Hash) and new.kind_of?(Hash))
          deep_safe_merge(old, new)
      elsif (old.kind_of?(Array) and new.kind_of?(Array))
          old.concat(new).uniq
      else
          new
      end
    end
  end

end
