require 'bio'
require 'fileutils'

list = File.open("list", 'r')
data = list.readlines
k = 0
data.each do |d|
  k = 1 if d.split("  ")[0] == "FN665653"

  if k == 1
  acc = d.split("  ")[0]
  gi = d.split("  ")[1]
  acc_v = acc.split(".")[0]

  if File.directory?(acc)
    begin
      f = File.open(acc + "/" + acc + ".gbk", 'r')
    rescue
      next
    end
    genbank = f.readlines
    version = nil
    genbank.each do |g|
      if /VERSION/.match(g)
         version = g.split(".")[1].split("\s")[0]
         break
      end
    end
    next if !/[\d]/.match(version)
    #File.rename(acc, acc.split(".")[0] + "." + version)

    entries = Dir.entries("./" + acc)
    entries.each do |e|
      if /#{acc}/.match(e)
        ext = e.split("#{acc}")[1]
        File.rename(acc + "/" + e, acc + "/" + acc.split(".")[0] + "." + version + ext.to_s)
      end
    end
    begin
      File.rename(acc, acc.split(".")[0] + "." + version)
    rescue Exception => e
      FileUtils.rm_rf(acc.split(".")[0] + "." + version) if File.directory?(acc.split(".")[0] + "." + version)
      File.rename(acc, acc.split(".")[0] + "." + version)
    end

    f.close
    puts acc

  elsif File.directory?(acc_v)
    puts acc_v
    begin
      f = File.open(acc_v + "/" + acc_v + ".gbk", 'r')
    rescue
      next
    end
    version = nil
    genbank = f.readlines
    genbank.each do |g|
      if /VERSION/.match(g)
         version = g.split(".")[1].split("\s")[0]
         break
      end
    end
    next if !/[\d]/.match(version)
    #File.rename(acc_v, acc_v.split(".")[0] + "." + version)

    entries = Dir.entries("./" + acc_v)
    entries.each do |e|
      if /#{acc_v}/.match(e)
        ext = e.split("#{acc_v}")[1]
        File.rename(acc_v + "/" + e, acc_v + "/" + acc_v.split(".")[0] + "." + version + ext.to_s)
      end
    end
    
    begin
      File.rename(acc_v, acc_v.split(".")[0] + "." + version)
    rescue Exception => e
      FileUtils.rm_rf(acc_v.split(".")[0] + "." + version) if File.directory?(acc_v.split(".")[0] + "." + version)
      File.rename(acc_v, acc_v.split(".")[0] + "." + version)
    end
    f.close
  end   
  end
end
