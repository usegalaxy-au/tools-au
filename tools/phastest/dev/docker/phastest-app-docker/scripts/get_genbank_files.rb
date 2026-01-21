require 'bio'

list = File.open("list", 'r')
data = list.readlines

#all_gis = ""
#all_accs = Array.new
k = 0
count = 0

data.each do |d|
  k = 1 if d.split("  ")[0] == "NC_013235.1"

  if k == 1
    acc = d.split("  ")[0]
    gi = d.split("  ")[1]
    acc_v = acc.split(".")[0]
  
    if File.directory?(acc)
      result = Bio::NCBI::REST::EFetch.nucleotide(gi, "gbwithparts")
      f = File.open(acc + "/" + acc + ".gbk", 'w')
      f.write(result)
      f.close
      #sleep 2
    elsif File.directory?(acc_v)
      result = Bio::NCBI::REST::EFetch.nucleotide(gi, "gbwithparts")
      f = File.open(acc_v + "/" + acc_v + ".gbk", 'w')
      f.write(result)
      f.close
      #sleep 2
    end
  end
  puts acc
  count = count + 1
  puts count
  #all_accs.push(acc)
  #all_gis = all_gis + ',' + d.split("  ")[1]
end

