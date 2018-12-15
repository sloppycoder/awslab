# some utilities for make using AWS SDK less painful

# convert a hash into AWS SDK's filter structure.
# e.g.
# {
#   filters: [
#     {
#       name: "vpc-id",
#       values: [
#         "vpc-a01106c2",
#       ],
#     },
#   ]
# }
def filters(h)
  { filters: h.collect { |k, v| { name: k.to_s, values: [v.to_s] } } }
end

# convert a hash into AWS SDK's tag structure.
# [
#   { key: 'Project', value: 'awslab' },
#   { key: 'Name', value: 'default' }
# ]
def tags(h)
  h.collect { |k, v| { key: k.to_s, value: v.to_s } }
end

def find_subnet(ec2_client, vpc_id, zone: nil, name: nil)
  result = ec2_client.describe_subnets(filters('vpc-id' => vpc_id))
  selected = result.subnets.select do |subnet|
    match_zone = zone.nil? || subnet.availability_zone == ec2_client.config.region + zone
    match_name = name.nil? || !subnet.tags.select { |tag| tag.key == 'Name' && tag.value == name }.empty?
    match_zone && match_name
  end
  !selected.empty? ? selected.first : nil
end
