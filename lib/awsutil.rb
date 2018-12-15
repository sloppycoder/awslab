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

def subnet_id_for_zone(ec2_client, vpc_id, zone = 'a')
  zone_name = ec2_client.config.region + zone
  result = ec2_client.describe_subnets(filters("vpc-id" => vpc_id))
  result.subnets.select {|subnet| subnet.availability_zone == zone_name}.first.subnet_id
end
