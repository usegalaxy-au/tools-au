require 'bio'

Dir.foreach(".") do |entry|

  if entry.split(".")[1].nil? && File.directory?(entry)
    puts entry

    result = Bio::NCBI::REST::EFetch.nucleotide(entry, "gbwithparts")
    f = File.open(entry + "/" + entry + ".gbk", 'w')
    f.write(result)
    f.close

    begin
      f = File.open(entry + "/" + entry + ".gbk", 'r')
    rescue
      next
    end
    genbank = f.readlines
    version = ""
    genbank.each do |g|
      if /^VERSION/.match(g)
         next if g.split(".")[1].nil?
         version = g.split(".")[1].split("\s")[0]
         break
      end
    end
    next if !/[\d]/.match(version)

    entries = Dir.entries("./" + entry)
    entries.each do |e|
      if /#{entry}/.match(e)
        ext = e.split("#{entry}")[1]
        File.rename(entry + "/" + e, entry + "/" + entry.split(".")[0] + "." + version + ext.to_s)
      end
    end
    begin
      File.rename(entry, entry.split(".")[0] + "." + version)
    rescue Exception => e
      FileUtils.rm_rf(entry.split(".")[0] + "." + version) if File.directory?(entry.split(".")[0] + "." + version)
      File.rename(entry, entry.split(".")[0] + "." + version)
      "Removed #{entry}"
    end

    f.close
  end
end
