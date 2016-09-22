Spree::Payment::Processing.module_eval do

  def close!
    return true if !source.respond_to?(:close!)

    source.close!(self)
  end
end