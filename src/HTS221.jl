# HTS221 humidity/temperature sensor.
# See http://www.st.com/resource/en/datasheet/hts221.pdf

const HTS221_t_coef  = Ref((NaN,NaN))
const HTS221_h_coef  = Ref((NaN,NaN))

function HTS221_calibrate()
    setaddr(HTS221_ADDRESS)   
    @assert smbus_read(0x0F) == 0xbc

    ## read temp calibration data
    # raw values
    t0_raw = smbus_read_pair(0x3c)
    t1_raw = smbus_read_pair(0x3e)

    # known °C
    u = smbus_read(0x35)
    t0_C = Float64(Int16(u & 0b0011) << 8 | smbus_read(0x32))/8
    t1_C = Float64(Int16(u & 0b1100) << 6 | smbus_read(0x33))/8
    
    m_t = (t1_C - t0_C)/(Float64(t1_raw) - Float64(t0_raw))
    k_t = t1_C - m_t*t1_raw
    HTS221_t_coef[] = (m_t, k_t)

    ## read humidity calibration data
    h0_raw = smbus_read_pair(0x36)
    h1_raw = smbus_read_pair(0x3a)

    h0_rH = Float64(smbus_read(0x30))/2
    h1_rH = Float64(smbus_read(0x31))/2

    m_h = (h1_rH - h0_rH)/(Float64(h1_raw) - Float64(h0_raw))
    k_h = h1_rH - m_h*h1_raw
    HTS221_h_coef[] = (m_h, k_h)

    return nothing
end

function HTS221_raw_temp()
    setaddr(HTS221_ADDRESS)
    CTRL_REG1 = 0x20
    CTRL_REG2 = 0x21
    
    smbus_write(CTRL_REG1, 0x00) # power down
    smbus_write(CTRL_REG1, 0x84) # power on, block update
    smbus_write(CTRL_REG2, 0x01) # one-shot aquisition

    while true
        sleep(0.025)
        smbus_read(CTRL_REG2) == 0 && break # check if finished
    end
    t_raw = smbus_read_pair(0x2a)
    smbus_write(CTRL_REG1, 0x00) # power down
    return t_raw
end

function HTS221_raw_humidity()
    setaddr(HTS221_ADDRESS)
    CTRL_REG1 = 0x20
    CTRL_REG2 = 0x21
    
    smbus_write(CTRL_REG1, 0x00) # power down
    smbus_write(CTRL_REG1, 0x84) # power on, block update
    smbus_write(CTRL_REG2, 0x01) # one-shot aquisition

    while true
        sleep(0.025)
        smbus_read(CTRL_REG2) == 0 && break # check if finished
    end
    h_raw = smbus_read_pair(0x28)
    smbus_write(CTRL_REG1, 0x00) # power down
    return h_raw
end

"""
    HTS221_temperature()

The temperature (in °C) from the HTS221 sensor.
"""
function HTS221_temperature()
    (m_t, k_t) = HTS221_t_coef[]
    t_raw = HTS221_raw_temp()
    m_t*t_raw + k_t
end

"""
    HTS221_humidity()

The relative humidity (as a percentage) from the HTS221 sensor.
"""
function HTS221_humidity()
    (m_h, k_h) = HTS221_h_coef[]
    h_raw = HTS221_raw_humidity()
    m_h*h_raw + k_h
end
